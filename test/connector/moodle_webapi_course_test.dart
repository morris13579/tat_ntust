import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_test/flutter_test.dart';

/// `core_enrol_get_users_courses` 這一份回應的本機判讀規格。
///
/// 這裡測的全是純函式：九個 getter 走 static 的 `Connector.getJsonByPost`，
/// 沒有可以注入假回應的地方，所以把「怎麼判讀」抽出來單獨驗證。
/// 樣本形狀照 moodle2.ntust.edu.tw 的實測結果：每一門課都有非空的
/// `idnumber`（13 碼，`<學年3><學期1><課號>`）與 `startdate` / `enddate`。
void main() {
  Map<String, dynamic> course({
    required int id,
    required String idnumber,
    String fullname = '',
    int startdate = 0,
    int enddate = 0,
  }) =>
      {
        'id': id,
        'idnumber': idnumber,
        'fullname': fullname,
        'startdate': startdate,
        'enddate': enddate,
      };

  group('matchCourseId：用 idnumber 對課號', () {
    test('課名裡含有別門課的課號時不會再配錯（舊行為只比 fullname）', () {
      // 一定要先比 idnumber：光靠 `fullname.contains(courseId)` 會先掃到
      // 「軟體工程（接續 AT10001）」，開出來是別門課的成績與名單。
      final courses = [
        course(id: 11, idnumber: '1141ZZ99999', fullname: '軟體工程（接續 AT10001）'),
        course(id: 22, idnumber: '1141AT10001', fullname: '計算機概論'),
      ];

      expect(MoodleWebApiConnector.matchCourseId(courses, 'AT10001'), '22');
    });

    test('idnumber 缺席時仍然退回 fullname 比對', () {
      // Moodle 規格上 idnumber 是選填（NTUST 實測 50 門課全都有），
      // 留 fallback 只會減少配錯、不會增加。
      final courses = [
        course(id: 33, idnumber: '', fullname: '計算機概論 AT10001'),
      ];

      expect(MoodleWebApiConnector.matchCourseId(courses, 'AT10001'), '33');
    });

    test('idnumber 直接就是課號（沒有學年學期前綴）也算命中', () {
      final courses = [course(id: 44, idnumber: 'AT10001')];

      expect(MoodleWebApiConnector.matchCourseId(courses, 'AT10001'), '44');
    });

    test('都沒配到就回 null', () {
      final courses = [
        course(id: 55, idnumber: '1141AT10002', fullname: '微積分')
      ];

      expect(MoodleWebApiConnector.matchCourseId(courses, 'AT10001'), isNull);
    });
  });

  group('courseIdsOfSemester：本機依學期前綴過濾', () {
    final courses = [
      course(id: 1, idnumber: '1141AT10001'),
      course(id: 2, idnumber: '1141AT10002'),
      course(id: 3, idnumber: '1132BC20003'),
      course(id: 4, idnumber: '113HDD30004'),
    ];

    test('歷史學期撈得到了（舊行為固定送 inprogress，過去的學期根本不在回應裡）', () {
      final ids = MoodleWebApiConnector.courseIdsOfSemester(
          courses, SemesterJson(year: '113', semester: '2'));

      expect(ids, ['BC20003']);
    });

    test('只回這個學期的課，不會把別的學期原封不動帶出來', () {
      // 必須先過濾再去前綴。直接對整份清單做 replaceAll(前綴, "") 的話，
      // 前綴對不上的課會連學年學期一起回傳，變成別的學期的課表。
      final ids = MoodleWebApiConnector.courseIdsOfSemester(
          courses, SemesterJson(year: '114', semester: '1'));

      expect(ids, ['AT10001', 'AT10002']);
    });

    test('暑期（學期 H）也照同一個前綴規則', () {
      final ids = MoodleWebApiConnector.courseIdsOfSemester(
          courses, SemesterJson(year: '113', semester: 'H'));

      expect(ids, ['DD30004']);
    });

    test('這學期真的沒有課時回空清單——它與「抓取失敗」的 null 是兩件事', () {
      final ids = MoodleWebApiConnector.courseIdsOfSemester(
          courses, SemesterJson(year: '110', semester: '1'));

      expect(ids, isEmpty);
    });

    test('學期格式不對就回空清單，不會整份清單都配上去', () {
      final ids = MoodleWebApiConnector.courseIdsOfSemester(
          courses, SemesterJson(year: '', semester: ''));

      expect(ids, isEmpty);
    });
  });

  group('currentSemesterOf：本機判斷目前學期', () {
    int unix(String iso) => DateTime.parse(iso).millisecondsSinceEpoch ~/ 1000;

    test('挑進行中的學期，不是清單裡的第一門課', () {
      // 清單含歷史學期，取 first 會拿到隨便一門舊課，只能靠日期挑。
      final courses = [
        course(
          id: 1,
          idnumber: '1132BC20003',
          startdate: unix('2025-02-01T00:00:00Z'),
          enddate: unix('2025-07-01T00:00:00Z'),
        ),
        course(
          id: 2,
          idnumber: '1141AT10001',
          startdate: unix('2025-09-01T00:00:00Z'),
          enddate: unix('2026-02-01T00:00:00Z'),
        ),
      ];

      final semester = MoodleWebApiConnector.currentSemesterOf(courses,
          now: DateTime.parse('2025-10-01T00:00:00Z'));

      expect(semester!.year, '114');
      expect(semester.semester, '1');
    });

    test('enddate 是 0 代表沒有結束日，不算已結束', () {
      final courses = [
        course(
          id: 1,
          idnumber: '1141AT10001',
          startdate: unix('2025-09-01T00:00:00Z'),
        ),
      ];

      final semester = MoodleWebApiConnector.currentSemesterOf(courses,
          now: DateTime.parse('2026-05-01T00:00:00Z'));

      expect(semester!.year, '114');
      expect(semester.semester, '1');
    });

    test('學期空檔沒有任何進行中的課時，退回清單裡最新的學期', () {
      final courses = [
        course(
          id: 1,
          idnumber: '1131AA10001',
          startdate: unix('2024-09-01T00:00:00Z'),
          enddate: unix('2025-02-01T00:00:00Z'),
        ),
        course(
          id: 2,
          idnumber: '1132BC20003',
          startdate: unix('2025-02-01T00:00:00Z'),
          enddate: unix('2025-07-01T00:00:00Z'),
        ),
      ];

      final semester = MoodleWebApiConnector.currentSemesterOf(courses,
          now: DateTime.parse('2025-08-01T00:00:00Z'));

      expect(semester!.year, '113');
      expect(semester.semester, '2');
    });

    test('沒有任何可辨識的 idnumber 就回 null', () {
      expect(
        MoodleWebApiConnector.currentSemesterOf([course(id: 1, idnumber: '')]),
        isNull,
      );
    });
  });

  group('isCourseMember：用 roles 篩老師', () {
    MoodleCoreEnrolGetUsers user(String fullName, List<String> roles) =>
        MoodleCoreEnrolGetUsers(
          fullName: fullName,
          roles: roles.map((e) => Roles(shortname: e)).toList(),
        );

    test('名字裡有「老師」兩個字的學生不再被藏起來（舊行為會藏）', () {
      expect(
        MoodleWebApiConnector.isCourseMember(
            user('B11012345@王老師', ['student'])),
        isTrue,
      );
    });

    test('名字裡沒有「老師」的老師會被藏起來（舊行為會留著）', () {
      expect(
        MoodleWebApiConnector.isCourseMember(
            user('teacher@陳大文', ['editingteacher'])),
        isFalse,
      );
      expect(
        MoodleWebApiConnector.isCourseMember(user('ta@助教', ['teacher'])),
        isFalse,
      );
    });

    test('roles 為空時保守地顯示，不是全部藏起來', () {
      // roles 拿不拿得到取決於權限。全部藏起來會讓名單變空，
      // 而 MoodleMemberTask 對空名單是直接報錯。
      expect(
        MoodleWebApiConnector.isCourseMember(user('B11012345@王小明', [])),
        isTrue,
      );
    });

    test('manager 這種站台管理角色刻意不篩掉', () {
      expect(
        MoodleWebApiConnector.isCourseMember(user('admin@管理員', ['manager'])),
        isTrue,
      );
    });
  });
}
