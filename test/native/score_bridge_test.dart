import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_get_grade_items.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_overview_course_grades.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/native/score_bridge.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeNtust extends NtustRepository {
  Result<ScoreRankJson> next = const Failed(FetchFailed());
  int calls = 0;

  @override
  Future<Result<ScoreRankJson>> getScoreRank() async {
    calls++;
    return next;
  }
}

class _FakeMoodle extends MoodleRepository {
  Result<MoodleCourseGradeList> grades = const Failed(FetchFailed());
  Result<MoodleUserGradesEntity> score = const Failed(FetchFailed());
  final List<bool> backgrounds = [];

  @override
  Future<Result<MoodleCourseGradeList>> getCourseGrades(
      {bool background = false}) async {
    backgrounds.add(background);
    return grades;
  }

  @override
  Future<Result<MoodleUserGradesEntity>> getCourseScore(
          String courseId) async =>
      score;
}

ScoreItemJson item(String name, String score,
        {String credit = '3', String remark = '', String dimension = ''}) =>
    ScoreItemJson(
      courseId: 'CS$name',
      name: name,
      credit: credit,
      score: score,
      generalDimension: dimension,
      remark: remark,
    );

SemesterScoreJson semester(
        String year, String term, List<ScoreItemJson> items) =>
    SemesterScoreJson(
        semester: SemesterJson(year: year, semester: term), item: items);

/// 原生版成績頁拿到的東西。排序、GPA、分數欄的字、Moodle 成績項目的顯示規則都在 Dart，
/// Swift 只照著畫——這些壞了，原生版會把還沒評分的課畫成不及格，或把課程總分整列弄丟。
void main() {
  setUpAll(() async => loadTestL10n());

  late _FakeNtust ntust;
  late _FakeMoodle moodle;
  late ScoreBridge bridge;

  setUp(() {
    resetAppStatics();
    Model.instance.setAccount('B11230223');
    AuthSession.instance = FakeAuthSession();
    ntust = _FakeNtust();
    moodle = _FakeMoodle();
    NtustRepository.instance = ntust;
    MoodleRepository.instance = moodle;
    bridge = ScoreBridge();
  });

  tearDown(() {
    NtustRepository.instance = NtustRepository();
    MoodleRepository.instance = MoodleRepository();
  });

  group('成績', () {
    test('沒登入不抓', () async {
      AuthSession.instance = FakeAuthSession(isSignedIn: false);

      final report = await bridge.load(false);

      expect(report.state, ScoreState.notSignedIn);
      expect(ntust.calls, 0);
    });

    test('沒有存著的才抓；學期新到舊、課照等第高到低，摘要跟著算', () async {
      ntust.next = Ok(ScoreRankJson(info: [
        semester('114', '2', [item('微積分', 'B')]),
        semester('115', '1', [
          item('作業系統', 'C', credit: '2'),
          item('資料結構', 'A+'),
          item('體育', 'E', credit: '0'),
        ]),
      ]));

      final report = await bridge.load(false);
      await bridge.load(false);

      expect(report.state, ScoreState.ok);
      expect(ntust.calls, 1, reason: '第二次讀存著的');
      expect(report.semesters.map((s) => s.semester), ['115-1', '114-2']);
      final latest = report.semesters.first;
      expect(latest.courses.map((c) => c.name), ['資料結構', '作業系統', '體育']);
      expect((latest.gpa, latest.credits, latest.failed), ('3.38', 5, 1));
      expect(latest.courses.last.failed, isTrue);
    });

    test('重新整理抓不到時，把存著的那一份一起回去', () async {
      ntust.next = Ok(ScoreRankJson(info: [
        semester('115', '1', [item('資料結構', 'A')]),
      ]));
      await bridge.load(false);
      ntust.next = const Failed(FetchFailed());

      final report = await bridge.load(true);

      expect(report.state, ScoreState.failed);
      expect(report.semesters.single.courses.single.label, 'A');
    });

    test('分數欄：通過、備註、尚未評分；沒有有效成績時沒有 GPA', () async {
      ntust.next = Ok(ScoreRankJson(info: [
        semester('115', '1', [
          item('服務學習', '通過', credit: '(0)', dimension: 'B'),
          item('英文', '', remark: '抵免'),
          item('專題', ''),
        ]),
      ]));

      final semesterReport = (await bridge.load(false)).semesters.single;

      expect(semesterReport.courses.map((c) => c.label), ['通過', '抵免', '尚未評分']);
      expect(semesterReport.courses.first.dimension, 'B');
      expect(semesterReport.courses.first.credits, 0);
      expect(semesterReport.courses.any((c) => c.failed), isFalse);
      expect(semesterReport.gpa, isNull);
    });
  });

  group('Moodle', () {
    test('進頁是背景載入、重新整理不是；失敗時帶訊息與登入狀態', () async {
      AuthSession.instance = FakeAuthSession(isSignedIn: false);
      moodle.grades = const Failed(NotSignedIn());

      final grades = await bridge.moodleGrades(false);
      await bridge.moodleGrades(true);

      expect(moodle.backgrounds, [true, false]);
      expect(grades.courses, isEmpty);
      expect(grades.error, isNotNull);
      expect(grades.signedIn, isFalse);
    });

    test('目前總分與學期', () async {
      moodle.grades = Ok(MoodleCourseGradeList(
        semester: SemesterJson(year: '115', semester: '1'),
        courses: [
          MoodleCourseGradeItem(
              courseId: 'CS3039701', name: '資料結構', grade: '85.00'),
        ],
      ));

      final grades = await bridge.moodleGrades(false);

      expect(grades.semester, '115-1');
      expect(grades.courses.single.grade, '85.00');
      expect(grades.error, isNull);
    });

    test('課程成績：課程總分補字、沒名字的項目跳過、破折號是尚未評分、空殼回饋不算回饋', () async {
      moodle.score = Ok(MoodleUserGradesEntity(gradeItems: [
        MoodleGradeItemEntity(
          id: 1,
          itemName: '期中考',
          itemType: 'mod',
          gradeFormatted: '80.00',
          percentageFormatted: '80.00 %',
          feedback: '<p>很好</p>',
        ),
        MoodleGradeItemEntity(id: 2, itemType: 'mod'),
        MoodleGradeItemEntity(
          id: 3,
          itemName: '作業',
          itemType: 'mod',
          gradeFormatted: '-',
          feedback: '<div class="no-overflow"></div>',
        ),
        MoodleGradeItemEntity(
            id: 4, itemType: 'course', gradeFormatted: '82.00'),
      ]));

      final rows = (await bridge.courseScore('CS3039701')).rows;

      expect(rows.map((r) => r.id), [1, 3, 4]);
      expect((rows[0].meta, rows[0].feedback), ('80.00 % · 回饋', '<p>很好</p>'));
      expect(
          (rows[1].grade, rows[1].meta, rows[1].feedback), (null, null, null));
      expect((rows[2].title, rows[2].kind, rows[2].grade),
          ('課程總分', GradeRowKind.course, '82.00'));
    });
  });
}
