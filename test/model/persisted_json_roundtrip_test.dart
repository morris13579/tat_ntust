import 'dart:convert';

import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_get_grade_items.dart';
import 'package:flutter_app/src/model/setting/setting_json.dart';
import 'package:flutter_app/src/model/userdata/user_data_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// 特徵化測試：凍結「真的會寫進 SharedPreferences」的 JSON 形狀。
///
/// 這些格式在沒有資料遷移的情況下不得變更（曾經因此丟過一次使用者資料）。
/// 因此除了 `toJson -> jsonEncode -> jsonDecode -> fromJson` 的欄位相等之外，
/// 每一組都額外斷言「編碼後最上層的 key 名稱」，讓任何欄位改名在 CI 直接紅燈。

/// 走一次真正的持久化路徑：物件 -> map -> 字串 -> map。
Map<String, dynamic> encodeDecode(Object object) =>
    jsonDecode(jsonEncode(object)) as Map<String, dynamic>;

CourseInfoJson sampleCourseInfo() => CourseInfoJson(
      main: CourseMainInfoJson(
        course: CourseMainJson(
          name: '計算機概論',
          id: 'CS1001',
          href: 'https://example.invalid/course',
          credits: '3',
          hours: '3',
          note: '備註',
          category: '必修',
          select: true,
          time: const {Day.monday: '1 2'},
        ),
        teacher: [TeacherJson(name: '王老師', href: 'https://example.invalid/t')],
        classroom: [ClassroomJson(name: 'TR-101', href: '')],
        openClass: [ClassJson(name: '資工一', href: '')],
      ),
    );

CourseTableJson sampleCourseTable() {
  final table = CourseTableJson(
    courseSemester: SemesterJson(year: '113', semester: '1'),
    studentId: 'B11000000',
    studentName: '測試學生',
  );
  table.courseInfoMap[Day.monday]![SectionNumber.t_1] = sampleCourseInfo();
  return table;
}

void main() {
  group('UserDataJson（SharedPreferences key: user_data）', () {
    test('round-trip 後三個欄位逐一相等', () {
      final origin = UserDataJson(
        account: 'B11000000',
        password: 'p@ss w0rd',
        mailPassword: 'mail p@ss',
      );

      final decoded = UserDataJson.fromJson(encodeDecode(origin));

      expect(decoded.account, origin.account);
      expect(decoded.password, origin.password);
      expect(decoded.mailPassword, origin.mailPassword);
      expect(decoded.isEmpty, isFalse);
    });

    test('最上層 key 名稱固定為 account / password / mailPassword', () {
      // 這些名字寫在已安裝使用者的 prefs 裡，改名等同資料遺失。
      expect(
        encodeDecode(UserDataJson()).keys.toSet(),
        {'account', 'password', 'mailPassword'},
      );
      // prefs 的 key 本身也一併釘住。
      expect(Model.userDataJsonKey, 'user_data');
    });

    test('缺少欄位的舊 blob 會補空字串而不是拋例外', () {
      final decoded = UserDataJson.fromJson(<String, dynamic>{});

      expect(decoded.account, '');
      expect(decoded.password, '');
      expect(decoded.mailPassword, '');
      expect(decoded.isEmpty, isTrue);
    });

    test('mailPassword 不算進 isEmpty', () {
      // isEmpty 代表「沒有登入 TAT」。信箱密碼是選用的，只有它有值不能讓
      // 這個帳號看起來像已登入。
      final onlyMail = UserDataJson(mailPassword: 'mail p@ss');

      expect(onlyMail.isEmpty, isTrue);
    });

    test('舊 blob 殘留的 webMailPassword 不會讓解碼失敗', () {
      // WebMail 功能移除後欄位跟著刪了，但已安裝使用者的 Keychain 裡還留著
      // 這個 key；解不開就等於把人登出。多出來的 key 要被忽略。
      //
      // 它**不會**被當成 mailPassword 撿回來用：那格裝的是 SSO 密碼，
      // 拿去登 IMAP 一定被拒（docs/WEBMAIL_IMAP.md 門檻 A）。
      final decoded = UserDataJson.fromJson(<String, dynamic>{
        'account': 'B11000000',
        'password': 'p@ss w0rd',
        'webMailPassword': 'sso-pw',
      });

      expect(decoded.account, 'B11000000');
      expect(decoded.password, 'p@ss w0rd');
      expect(decoded.mailPassword, '');
    });
  });

  group('SettingJson（SharedPreferences key: setting）', () {
    test('round-trip 後 course 與 other 兩層都逐一相等', () {
      final origin = SettingJson(
        course: CourseSettingJson(info: sampleCourseTable()),
        other: OtherSettingJson(
          lang: 'zh',
          useExternalVideoPlayer: true,
          useMoodleWebApi: false,
        ),
      );

      final decoded = SettingJson.fromJson(encodeDecode(origin));

      expect(decoded.other.lang, 'zh');
      expect(decoded.other.useExternalVideoPlayer, isTrue);
      expect(decoded.other.useMoodleWebApi, isFalse);

      final info = decoded.course.info;
      expect(info.studentId, 'B11000000');
      expect(info.studentName, '測試學生');
      expect(info.courseSemester.year, '113');
      expect(info.courseSemester.semester, '1');

      final course = info.courseInfoMap[Day.monday]![SectionNumber.t_1]!;
      expect(course.main.course.id, 'CS1001');
      expect(course.main.course.name, '計算機概論');
      expect(course.main.course.credits, '3');
      expect(course.main.course.time[Day.monday], '1 2');
      expect(course.main.teacher.single.name, '王老師');
      expect(course.main.classroom.single.name, 'TR-101');
      expect(course.main.openClass.single.name, '資工一');
    });

    test('最上層 key 是 course / other，巢狀 key 是 info 與三個 other 欄位', () {
      final encoded = encodeDecode(SettingJson());

      expect(encoded.keys.toSet(), {'course', 'other'});
      expect((encoded['course'] as Map).keys.toSet(), {'info'});
      expect((encoded['other'] as Map).keys.toSet(), {
        'lang',
        'useExternalVideoPlayer',
        'useMoodleWebApi',
      });
      expect(Model.settingJsonKey, 'setting');
    });

    test('缺少 useMoodleWebApi 與 useExternalVideoPlayer 時採用預設值', () {
      // 要移除這兩個欄位的話，舊裝置的 blob 仍會帶著它們、新裝置的會缺少；
      // 這個測試釘住「缺少時的預設值」。
      final decoded = OtherSettingJson.fromJson(<String, dynamic>{
        'lang': 'en',
      });

      expect(decoded.lang, 'en');
      expect(decoded.useMoodleWebApi, isTrue);
      expect(decoded.useExternalVideoPlayer, isFalse);
    });

    test('完全空的 setting blob 也能解出可用的預設物件', () {
      final decoded = SettingJson.fromJson(<String, dynamic>{});

      expect(decoded.isEmpty, isTrue);
      expect(decoded.other.lang, '');
      expect(decoded.other.useMoodleWebApi, isTrue);
      // 預設建構的課表會替八個 Day 都建好空 map。
      expect(decoded.course.info.courseInfoMap.length, Day.values.length);
    });

    test('Day 與 SectionNumber 的 JSON key 逐字等於 enum 名稱', () {
      // 這些字串就是課表 JSON 的 map key，
      // 改名或加不一致的 @JsonValue 會讓 getInstance 清空課表與整個 setting blob。
      final encoded = encodeDecode(sampleCourseTable());
      final courseInfoMap = encoded['courseInfoMap'] as Map<String, dynamic>;

      expect(encoded.keys.toSet(),
          {'courseSemester', 'studentId', 'studentName', 'courseInfoMap'});
      expect(courseInfoMap.keys.toList(), [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
        'unKnown',
      ]);
      expect((courseInfoMap['monday'] as Map).keys.toList(), ['t_1']);
      // CourseMainJson.time 也是以 Day 名稱當 key。
      final main = (courseInfoMap['monday'] as Map)['t_1']['main'];
      expect((main['course']['time'] as Map).keys.toList(), ['monday']);
    });
  });

  group('MoodleTokenEntity（SharedPreferences key: moodle_token）', () {
    test('round-trip 後三個欄位逐一相等', () {
      final origin = MoodleTokenEntity('sig-abc', 'ws-token', 'priv-token');

      final decoded = MoodleTokenEntity.fromJson(encodeDecode(origin));

      expect(decoded.signature, 'sig-abc');
      expect(decoded.token, 'ws-token');
      expect(decoded.privateToken, 'priv-token');
    });

    test('最上層 key 是 signature / token / private_token（駝峰與底線混用）', () {
      // privateToken 欄位對應的 JSON key 是 snake_case 的 private_token，
      // 這是手寫 toJson 的結果，改成 json_serializable 時要保留同樣的名稱。
      expect(
        encodeDecode(MoodleTokenEntity('s', 't', 'p')).keys.toList(),
        ['signature', 'token', 'private_token'],
      );
    });

    test('缺少 private_token 的舊 blob 會拋 TypeError（現況，非回傳 null）', () {
      // 已知問題：手寫的 fromJson 直接把 json["private_token"] 餵給
      // 非 nullable 的 String 參數，缺欄位時是 TypeError 而不是可辨識的錯誤，
      // 而 Model.getMoodleToken 沒有 try/catch。
      expect(
        () => MoodleTokenEntity.fromJson(<String, dynamic>{
          'signature': 'sig',
          'token': 'ws-token',
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('MoodleUserGradesEntity（Moodle 成績快取，cache_moodle_score）', () {
    MoodleUserGradesEntity sample() => MoodleUserGradesEntity(
          courseId: 123,
          courseIdNumber: '1141AT10001',
          userId: 456,
          userFullName: '測試學生',
          userIdNumber: 'B11000000',
          maxDepth: 4,
          gradeItems: [
            MoodleGradeItemEntity(
              id: 11,
              itemName: '作業一',
              itemType: 'mod',
              itemModule: 'assign',
              gradeFormatted: '90.00',
              percentageFormatted: '90.00 %',
              weightFormatted: '10.00 %',
              rangeFormatted: '0&ndash;100',
              feedback: '<p>不錯</p>',
              feedbackFormat: 1,
            ),
            MoodleGradeItemEntity(
              id: 12,
              itemName: '課程總分',
              itemType: 'course',
              gradeFormatted: '85.00',
            ),
          ],
        );

    test('toJson 的最上層 key 用 Moodle 的原始名稱（全小寫，非駝峰）', () {
      // 快取存的就是 Moodle 回應的形狀，改名等於讓既有快取全部讀不回來。
      final encoded = encodeDecode(sample());

      expect(encoded.keys.toList(), [
        'courseid',
        'courseidnumber',
        'userid',
        'userfullname',
        'useridnumber',
        'maxdepth',
        'gradeitems',
      ]);
      expect(encoded['gradeitems'], isA<List>());
      expect((encoded['gradeitems'] as List).first['itemname'], '作業一');
    });

    test('round-trip 對稱：自家寫出去的 blob 讀得回來', () {
      final encoded = encodeDecode(sample());
      final restored = MoodleUserGradesEntity.fromJson(encoded);

      expect(restored.courseId, 123);
      expect(restored.userId, 456);
      expect(restored.userFullName, '測試學生');
      expect(restored.maxDepth, 4);
      expect(restored.gradeItems.length, 2);
      expect(restored.gradeItems.last.itemType, 'course');
      expect(restored.gradeItems.last.isCourseTotal, isTrue);
      expect(restored.gradeItems.first.feedback, '<p>不錯</p>');
    });

    test('fromJson 直接吃 Moodle 實測回應的形狀（graderaw 是 null，*formatted 有值）', () {
      // moodle2.ntust.edu.tw 實測：學生 token 拿不到原始分數，graderaw /
      // gradedategraded / scaleid 全是 null，只有 *formatted 有值。
      // 把這些選用欄位寫成必填的話這裡會整包拋，成績頁直接掛掉。
      final entity = MoodleUserGradesEntity.fromJson(<String, dynamic>{
        'courseid': 28914,
        'courseidnumber': '1141AT10001',
        'userid': 5252,
        'userfullname': '測試學生',
        'useridnumber': 'B11000000',
        'maxdepth': 2,
        'gradeitems': [
          {
            'id': 991,
            'itemname': '課程總分',
            'itemtype': 'course',
            'itemmodule': null,
            'iteminstance': 28914,
            'itemnumber': null,
            'idnumber': null,
            'categoryid': null,
            'outcomeid': null,
            'scaleid': null,
            'locked': null,
            'cmid': null,
            'weightraw': 0,
            'weightformatted': '',
            'graderaw': null,
            'gradedatesubmitted': 1740000000,
            'gradedategraded': null,
            'gradehiddenbydate': false,
            'gradeneedsupdate': false,
            'gradeishidden': false,
            'gradeislocked': null,
            'gradeisoverridden': null,
            'gradeformatted': '85.00',
            'grademin': 0,
            'grademax': 100,
            'rangeformatted': '0&ndash;100',
            'percentageformatted': '85.00 %',
            'feedback': '',
            'feedbackformat': 0,
          }
        ],
      });

      final item = entity.gradeItems.single;
      expect(item.gradeRaw, isNull);
      expect(item.gradeFormatted, '85.00');
      expect(item.percentageFormatted, '85.00 %');
      expect(item.rangeFormatted, '0&ndash;100');
      expect(item.isCourseTotal, isTrue);
      expect(item.itemModule, isNull);
      expect(item.gradeIsHidden, isFalse);
    });

    test('缺席與 null 的欄位一律退回預設值，不會拋（不要把選用欄位改成必填）', () {
      // 把選用欄位改成必填會讓整個成績頁掛掉。
      final entity = MoodleUserGradesEntity.fromJson(<String, dynamic>{
        'gradeitems': [<String, dynamic>{}],
      });

      expect(entity.courseId, 0);
      expect(entity.userFullName, '');
      expect(entity.gradeItems.single.itemName, isNull);
      expect(entity.gradeItems.single.itemType, '');
      expect(entity.gradeItems.single.gradeFormatted, '');
      expect(entity.gradeItems.single.isCourseTotal, isFalse);
    });

    test('外層 usergrades 缺席時退回空清單', () {
      expect(MoodleGradeItemsEntity.fromJson(<String, dynamic>{}).userGrades,
          isEmpty);
    });

    test('grademin / grademax 是整數時也解得開（宣告成 num 而不是 double）', () {
      // Moodle 的 REST JSON 對 100.0 會送成 100，宣告 double 會直接拋。
      final item = MoodleGradeItemEntity.fromJson(<String, dynamic>{
        'grademin': 0,
        'grademax': 100,
        'weightraw': 0.15,
      });

      expect(item.gradeMin, 0);
      expect(item.gradeMax, 100);
      expect(item.weightRaw, 0.15);
    });
  });

  /// SemesterJson 也會落磁碟，但上面那組「最上層 key」的斷言不會往
  /// courseSemester 裡面走——巢狀型別的欄位增刪會無聲通過，
  /// 所以這裡補上升版與降版兩個方向的斷言。
  group('SemesterJson 拿掉 urlPath 之後的相容性', () {
    test('編碼出來只有 year 與 semester', () {
      expect(
          encodeDecode(SemesterJson(year: '113', semester: '1')).keys.toSet(),
          {'year', 'semester'});
    });

    test('升版：舊版寫的 urlPath 會被安靜忽略，其餘欄位照常還原', () {
      // 舊版實際寫進 SharedPreferences 的形狀。
      final legacy =
          jsonDecode('{"year":"113","semester":"1","urlPath":"/113/1"}')
              as Map<String, dynamic>;

      final restored = SemesterJson.fromJson(legacy);

      expect(restored.year, '113');
      expect(restored.semester, '1');
    });

    test('降版：新版寫的資料少了 urlPath，舊版讀回來會套用它自己的空字串預設', () {
      // 舊版產生的 fromJson 是 `json['urlPath'] as String? ?? ""`，
      // 這裡用同一個運算式模擬，確認缺鍵不會拋。
      final current = encodeDecode(SemesterJson(year: '113', semester: '1'));

      expect(current.containsKey('urlPath'), isFalse);
      expect(current['urlPath'] as String? ?? '', '');
    });

    test('巢狀在課表裡也是同一個形狀', () {
      final encoded = encodeDecode(sampleCourseTable());

      expect((encoded['courseSemester'] as Map).keys.toSet(),
          {'year', 'semester'});
    });
  });
}
