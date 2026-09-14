import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/native/course_detail_bridge.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeNtust extends NtustRepository {
  Result<CourseExtraInfoJson> next = const Failed(FetchFailed());
  SemesterJson? semester;

  @override
  Future<Result<CourseExtraInfoJson>> getCourseExtraInfo(
      String courseId, SemesterJson semester) async {
    this.semester = semester;
    return next;
  }
}

class _FakeMoodle extends MoodleRepository {
  Result<List<MoodleCoreEnrolGetUsers>> next = const Failed(FetchFailed());
  int calls = 0;

  @override
  Future<Result<List<MoodleCoreEnrolGetUsers>>> getMembers(
      String courseId) async {
    calls++;
    return next;
  }
}

CourseExtraInfoJson info({String grading = '期中 30% 期末 40% 作業 30%'}) =>
    CourseExtraInfoJson(
      semester: '1151',
      courseNo: 'CS3039701',
      courseName: '資料結構',
      courseTeacher: '王老師',
      creditPoint: '3',
      courseTimes: '3',
      practicalTimes: '0',
      requireOption: '必',
      allYear: '半',
      chooseStudent: '40',
      threeStudent: '10',
      allStudent: '50',
      restrict1: '60',
      restrict2: '50',
      nTURestrict: '5',
      nTNURestrict: '5',
      courseObject: '學會資料結構',
      courseGrading: grading,
      courseTextbook: 'CLRS',
      courseURL: 'https://example.com/ds',
    );

/// 原生版的課程資訊與修課學生。哪些欄位上表格、評量方式拆不拆得開、名單什麼時候重打，
/// 都是 Dart 的判斷——壞了，原生版會多出一列空欄位，或每進一次名單頁就等一次那支慢的 API。
void main() {
  setUpAll(() async => loadTestL10n());

  late _FakeNtust ntust;
  late _FakeMoodle moodle;
  late CourseDetailBridge bridge;

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    ntust = _FakeNtust();
    moodle = _FakeMoodle();
    NtustRepository.instance = ntust;
    MoodleRepository.instance = moodle;
    bridge = CourseDetailBridge();
  });

  tearDown(() {
    NtustRepository.instance = NtustRepository();
    MoodleRepository.instance = MoodleRepository();
  });

  group('課程資訊', () {
    test('學期照課表的那一個查；空的欄位不上表格，上限缺一個就不寫', () async {
      ntust.next = Ok(info());

      final result = await bridge.detail('CS3039701', '115-1');
      final detail = result.info!;

      expect((ntust.semester?.year, ntust.semester?.semester), ('115', '1'));
      expect(detail.subtitle, 'CS3039701 · 1151');
      expect(detail.chips, ['必', '3 學分', '半']);
      expect(detail.facts.map((f) => f.value), [
        '王老師',
        '3 / 0 小時',
        '50 人（40 / 10）',
      ]);
      expect(detail.facts.last.footnote, '上限 60 · 本校 50 · 校際 10');
      expect(detail.memberCount, '50');
      expect(detail.objective?.body, '學會資料結構');
      expect(detail.courseUrl, 'https://example.com/ds');
      expect(detail.more.map((m) => (m.title, m.body)), [('教科書', 'CLRS')]);
      expect(result.error, isNull);
    });

    test('評量方式拆得出百分比就是表格，拆不出來整段當文字', () async {
      ntust.next = Ok(info());
      final table = (await bridge.detail('CS3039701', '115-1')).info!;
      expect(table.grading?.map((g) => (g.label, g.percent)),
          [('期中', '30%'), ('期末', '40%'), ('作業', '30%')]);
      expect(table.gradingText, isNull);

      ntust.next = Ok(info(grading: '依上課表現評分。'));
      final prose = (await bridge.detail('CS3039701', '115-1')).info!;
      expect(prose.grading, isNull);
      expect(prose.gradingText, '依上課表現評分。');
    });

    test('抓不到時帶著原因回去', () async {
      ntust.next = const Failed(FetchFailed('查不到課程資訊'));

      final result = await bridge.detail('CS3039701', '115-1');

      expect(result.info, isNull);
      expect(result.error, '查不到課程資訊');
    });
  });

  group('修課學生', () {
    final roster = [
      MoodleCoreEnrolGetUsers(
          fullName: 'B11230223 @ 王小明', profileImageUrlSmall: 'https://img/1'),
      MoodleCoreEnrolGetUsers(fullName: 'B11230224 @ 李大華'),
    ];

    test('姓名與學號拆開；抓過就不重打，重新整理才重打', () async {
      moodle.next = Ok(roster);

      final first = await bridge.members('CS3039701', false);
      await bridge.members('CS3039701', false);

      expect(first.members.map((m) => (m.name, m.studentId, m.avatarUrl)), [
        ('王小明', 'B11230223', 'https://img/1'),
        ('李大華', 'B11230224', null),
      ]);
      expect(moodle.calls, 1);

      await bridge.members('CS3039701', true);
      expect(moodle.calls, 2);
    });

    test('搜尋姓名或學號在本機做，不分大小寫', () async {
      moodle.next = Ok(roster);
      await bridge.members('CS3039701', false);

      expect(bridge.filterMembers('CS3039701', '李').map((m) => m.name),
          ['李大華']);
      expect(bridge.filterMembers('CS3039701', 'b11230223').map((m) => m.name),
          ['王小明']);
      expect(bridge.filterMembers('CS0000000', '王'), isEmpty);
    });

    test('抓不到時帶原因與登入狀態，原生版才知道要給重試還是登入', () async {
      AuthSession.instance = FakeAuthSession(isSignedIn: false);
      moodle.next = const Failed(FetchFailed('名單抓不到'));

      final result = await bridge.members('CS3039701', false);

      expect(result.members, isEmpty);
      expect(result.error, '名單抓不到');
      expect(result.signedIn, isFalse);
    });
  });
}
