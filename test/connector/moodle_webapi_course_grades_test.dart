import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_overview_course_grades.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';

/// `gradereport_overview_get_course_grades` 這一份回應的本機判讀規格，以及
/// 它與 `core_enrol_get_users_courses` 的 join。
///
/// 判讀與 join 都抽成公開純函式（同 `userGradesOf` / `courseIdsOfSemester` 的
/// 慣例）；請求那一段用 `wsPost` 換掉傳輸層，不碰網路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetAppStatics);
  tearDown(resetAppStatics);

  Map<String, dynamic> course({
    required int id,
    required String idnumber,
    String fullname = '',
    String shortname = '',
    int startdate = 0,
    int enddate = 0,
  }) =>
      {
        'id': id,
        'idnumber': idnumber,
        'fullname': fullname,
        'shortname': shortname,
        'startdate': startdate,
        'enddate': enddate,
      };

  MoodleOverviewGrade grade(int courseid, String value) =>
      MoodleOverviewGrade(courseid: courseid, grade: value);

  SemesterJson semester(String year, String s) =>
      SemesterJson(year: year, semester: s);

  /// 依序回 [responses]；回傳的清單記錄每一次送出的參數。
  List<ConnectorParameter> stubWs(List<dynamic> responses) {
    final captured = <ConnectorParameter>[];
    final queue = List<dynamic>.from(responses);
    MoodleWebApiConnector.wsPost = (parameter) async {
      captured.add(parameter);
      return queue.removeAt(0);
    };
    return captured;
  }

  group('courseGradesOf', () {
    test('正常回應解出 courseid 與 grade', () {
      final grades = MoodleWebApiConnector.courseGradesOf({
        'grades': [
          {'courseid': 1234, 'grade': '85.55', 'rawgrade': '85.55000'},
          {'courseid': 1235, 'grade': '-', 'rawgrade': null},
        ],
        'warnings': <dynamic>[],
      });

      expect(grades, hasLength(2));
      expect(grades![0].courseid, 1234);
      expect(grades[0].grade, '85.55');
      expect(grades[1].grade, '-');
    });

    test('rawgrade 是字串、float 或 null 都不影響解析（那個欄位沒建模）', () {
      for (final raw in [<String, dynamic>{}, 85.55, null, '85.55000']) {
        final grades = MoodleWebApiConnector.courseGradesOf({
          'grades': [
            {'courseid': 1, 'grade': '85.55', if (raw != null) 'rawgrade': raw},
          ],
        });
        expect(grades!.single.grade, '85.55');
      }
    });

    test('帶 rank 的回應照樣解得開（站台開了 showrank 才有這個欄位）', () {
      final grades = MoodleWebApiConnector.courseGradesOf({
        'grades': [
          {'courseid': 7, 'grade': 'A', 'rawgrade': '92.0', 'rank': 3},
        ],
      });

      expect(grades!.single.grade, 'A');
    });

    test('空的 grades 是合法結果，回空清單而不是 null', () {
      // 一門課都沒開放成績的學生不該看到錯誤頁。
      final grades = MoodleWebApiConnector.courseGradesOf(
          {'grades': <dynamic>[], 'warnings': <dynamic>[]});

      expect(grades, isNotNull);
      expect(grades, isEmpty);
    });

    test('形狀不對一律回 null——錯誤包不能被當成「零門課」', () {
      expect(
          MoodleWebApiConnector.courseGradesOf('<html>login</html>'), isNull);
      expect(
          MoodleWebApiConnector.courseGradesOf({
            'exception': 'moodle_exception',
            'errorcode': 'accessexception',
            'message': 'Access control exception',
          }),
          isNull);
      expect(MoodleWebApiConnector.courseGradesOf({'grades': 'x'}), isNull);
      expect(MoodleWebApiConnector.courseGradesOf(null), isNull);
    });
  });

  group('joinCourseGrades', () {
    test('用 Moodle 內部 id 對起來，輸出的 courseId 是去掉前綴的課號', () {
      final rows = MoodleWebApiConnector.joinCourseGrades(
        [course(id: 11, idnumber: '1141AT10001', fullname: '計算機概論')],
        [grade(11, '85.55')],
        semester('114', '1'),
      );

      expect(rows.single.courseId, 'AT10001');
      expect(rows.single.name, '計算機概論');
      expect(rows.single.grade, '85.55');
    });

    test('只留這個學期的課，別的學期整列不出現', () {
      final rows = MoodleWebApiConnector.joinCourseGrades(
        [
          course(id: 11, idnumber: '1141AT10001', fullname: '計算機概論'),
          course(id: 22, idnumber: '1132BC20003', fullname: '微積分'),
        ],
        [grade(11, '85'), grade(22, '90')],
        semester('114', '1'),
      );

      expect(rows.map((e) => e.courseId), ['AT10001']);
    });

    test('順序照 grades[] 的順序，不重新排序', () {
      // 那就是 Moodle 網頁版總覽表的順序，也省掉中文課名的排序規則。
      final rows = MoodleWebApiConnector.joinCourseGrades(
        [
          course(id: 11, idnumber: '1141AT10001', fullname: 'A'),
          course(id: 22, idnumber: '1141BB20002', fullname: 'B'),
        ],
        [grade(22, '90'), grade(11, '85')],
        semester('114', '1'),
      );

      expect(rows.map((e) => e.courseId), ['BB20002', 'AT10001']);
    });

    test('grades 裡有一筆對不到課程清單就丟掉，其餘照常', () {
      final rows = MoodleWebApiConnector.joinCourseGrades(
        [course(id: 11, idnumber: '1141AT10001', fullname: 'A')],
        [grade(99, '77'), grade(11, '85')],
        semester('114', '1'),
      );

      expect(rows.map((e) => e.courseId), ['AT10001']);
    });

    test('idnumber 剝完是空的就丟掉，保證每一列都點得開', () {
      final rows = MoodleWebApiConnector.joinCourseGrades(
        [
          course(id: 11, idnumber: '1141', fullname: '前綴而已'),
          course(id: 22, idnumber: '', fullname: '沒有 idnumber'),
        ],
        [grade(11, '85'), grade(22, '90')],
        semester('114', '1'),
      );

      expect(rows, isEmpty);
    });

    test('grade 是 "-" 時原樣輸出，不解析成數字', () {
      // 藏起來的總分與「還沒有成績」在伺服器端都是 "-"，客戶端分不出來。
      final rows = MoodleWebApiConnector.joinCourseGrades(
        [course(id: 11, idnumber: '1141AT10001', fullname: 'A')],
        [grade(11, '-')],
        semester('114', '1'),
      );

      expect(rows.single.grade, '-');
    });

    test('grade 是空字串（無評分／文字型態的課程總分）時輸出 "-"', () {
      // 畫成空白會像壞掉。
      final rows = MoodleWebApiConnector.joinCourseGrades(
        [course(id: 11, idnumber: '1141AT10001', fullname: 'A')],
        [grade(11, '')],
        semester('114', '1'),
      );

      expect(rows.single.grade, '-');
    });

    test('grade 的 HTML 實體會被還原（量尺與等第會過 format_string）', () {
      final rows = MoodleWebApiConnector.joinCourseGrades(
        [course(id: 11, idnumber: '1141AT10001', fullname: 'A')],
        [grade(11, '通過 &amp; 優良')],
        semester('114', '1'),
      );

      expect(rows.single.grade, '通過 & 優良');
    });

    test('fullname 優先、含 &amp; 會還原、前綴會剝掉', () {
      final rows = MoodleWebApiConnector.joinCourseGrades(
        [
          course(
            id: 11,
            idnumber: '1141AT10001',
            fullname: '114.1【AT10001】Design &amp; Analysis',
            shortname: '設計',
          ),
        ],
        [grade(11, '85')],
        semester('114', '1'),
      );

      expect(rows.single.name, 'Design & Analysis');
    });

    test('fullname 為空時退回 shortname，兩個都空就退回課號', () {
      final rows = MoodleWebApiConnector.joinCourseGrades(
        [
          course(id: 11, idnumber: '1141AT10001', shortname: '計概'),
          course(id: 22, idnumber: '1141BB20002'),
        ],
        [grade(11, '85'), grade(22, '90')],
        semester('114', '1'),
      );

      expect(rows[0].name, '計概');
      expect(rows[1].name, 'BB20002');
    });

    test('學期前綴長度不是 4 就回空清單，不硬比', () {
      final rows = MoodleWebApiConnector.joinCourseGrades(
        [course(id: 11, idnumber: '1141AT10001', fullname: 'A')],
        [grade(11, '85')],
        semester('11', '1'),
      );

      expect(rows, isEmpty);
    });
  });

  group('getCourseGrades', () {
    int unix(String iso) => DateTime.parse(iso).millisecondsSinceEpoch ~/ 1000;

    List<Map<String, dynamic>> currentCourses() => [
          course(
            id: 11,
            idnumber: '1141AT10001',
            fullname: '計算機概論',
            startdate: unix('2020-09-01T00:00:00Z'),
          ),
        ];

    Map<String, dynamic> gradesResponse() => {
          'grades': [
            {'courseid': 11, 'grade': '85.55', 'rawgrade': '85.55000'},
          ],
          'warnings': <dynamic>[],
        };

    test('兩趟請求：先課程清單再總分，第二趟只送真的 userid', () async {
      MoodleWebApiConnector.userId = '42';
      final captured = stubWs([currentCourses(), gradesResponse()]);

      final list = await MoodleWebApiConnector.getCourseGrades();

      expect(captured, hasLength(2));
      expect((captured[0].data as Map)['wsfunction'],
          'core_enrol_get_users_courses');
      final data = captured[1].data as Map;
      expect(data['wsfunction'], 'gradereport_overview_get_course_grades');
      expect(data['userid'], '42');
      // 這一支不跑 format_text，送 moodlewssetting* 只是白花參數。
      expect(data.containsKey('moodlewssettingfilter'), isFalse);
      expect(data.containsKey('moodlewssettingfileurl'), isFalse);

      expect(list!.semester.year, '114');
      expect(list.semester.semester, '1');
      expect(list.courses.single.courseId, 'AT10001');
      expect(list.courses.single.grade, '85.55');
    });

    test('課程清單已被記憶時只剩一趟', () async {
      MoodleWebApiConnector.userId = '42';
      stubWs([currentCourses(), gradesResponse()]);
      await MoodleWebApiConnector.getCourseGrades();

      final captured = stubWs([gradesResponse()]);
      final list = await MoodleWebApiConnector.getCourseGrades();

      expect(captured, hasLength(1));
      expect((captured.single.data as Map)['wsfunction'],
          'gradereport_overview_get_course_grades');
      expect(list!.courses, hasLength(1));
    });

    test('沒有任何可辨識的學期前綴 → 回 null，不是一份空清單', () async {
      // 學期猜錯會端出一份看起來很正常、其實是別學期的清單。
      MoodleWebApiConnector.userId = '42';
      final captured = stubWs([
        [course(id: 11, idnumber: '')]
      ]);

      expect(await MoodleWebApiConnector.getCourseGrades(), isNull);
      // 學期都不知道就不必再打第二趟。
      expect(captured, hasLength(1));
    });

    test('回應是錯誤包 → null，onApiError 收到帶 wsFunction 的例外，且不算 token 失效', () async {
      MoodleWebApiConnector.userId = '42';
      final errors = <MoodleApiException>[];
      MoodleWebApiConnector.onApiError = errors.add;
      stubWs([
        currentCourses(),
        {
          'exception': 'moodle_exception',
          'errorcode': 'accessexception',
          'message': 'Access control exception',
        },
      ]);

      expect(await MoodleWebApiConnector.getCourseGrades(), isNull);
      expect(
          errors.single.wsFunction, 'gradereport_overview_get_course_grades');
      expect(errors.single.isInvalidToken, isFalse,
          reason: 'accessexception 不可以觸發重新登入，否則會變成登入迴圈');
    });

    test('回應少了 grades → null，而且回報一個帶 wsFunction 的例外', () async {
      MoodleWebApiConnector.userId = '42';
      final errors = <MoodleApiException>[];
      MoodleWebApiConnector.onApiError = errors.add;
      stubWs([
        currentCourses(),
        {'warnings': <dynamic>[]},
      ]);

      expect(await MoodleWebApiConnector.getCourseGrades(), isNull);
      expect(
          errors.single.wsFunction, 'gradereport_overview_get_course_grades');
    });

    test('空的 grades 是合法結果：回一份空清單，學期照樣有', () async {
      MoodleWebApiConnector.userId = '42';
      stubWs([
        currentCourses(),
        {'grades': <dynamic>[], 'warnings': <dynamic>[]},
      ]);

      final list = await MoodleWebApiConnector.getCourseGrades();

      expect(list, isNotNull);
      expect(list!.courses, isEmpty);
      expect(list.semester.year, '114');
    });
  });
}
