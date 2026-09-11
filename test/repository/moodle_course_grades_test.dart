import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_overview_course_grades.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 不打網路的 [MoodleRepository]：只換掉「真的去問 Moodle」那一步。
class _FakeRepo extends MoodleRepository {
  MoodleCourseGradeList? next;
  int calls = 0;

  @override
  Future<MoodleCourseGradeList?> fetchCourseGrades() async {
    calls++;
    return next;
  }
}

/// [MoodleRepository.getCourseGrades] 的行為：三態、快取、背景模式。
void main() {
  late _FakeRepo repo;
  late FakeAuthSession auth;
  late RecordingUi ui;
  late FakeConnectivityProbe net;

  MoodleCourseGradeList twoCourses() => MoodleCourseGradeList(
        semester: SemesterJson(year: '114', semester: '1'),
        courses: [
          MoodleCourseGradeItem(
              courseId: 'AT10001', name: '計算機概論', grade: '85.55'),
          MoodleCourseGradeItem(courseId: 'BB20002', name: '微積分', grade: '-'),
        ],
      );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    auth = FakeAuthSession();
    ui = RecordingUi();
    net = FakeConnectivityProbe();
    MoodleRepository.instance = repo;
    AuthSession.instance = auth;
    TaskUiDelegate.instance = ui;
    ConnectivityProbe.instance = net;
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  Future<MoodleCourseGradeList?> cached() =>
      CacheStore.instance.read(MoodleRepository.courseGradesKey());

  test('抓到就回 Ok，並寫進快取（連學期一起）', () async {
    repo.next = twoCourses();

    final result = await MoodleRepository.instance.getCourseGrades();

    expect(result, isA<Ok<MoodleCourseGradeList>>());
    expect(result.dataOrNull!.courses.map((e) => e.courseId),
        ['AT10001', 'BB20002']);
    final blob = await cached();
    expect(blob!.courses.map((e) => e.grade), ['85.55', '-']);
    expect(blob.semester, SemesterJson(year: '114', semester: '1'));
    expect(repo.calls, 1);
  });

  test('空清單也是 Ok，快取存的是空清單', () async {
    // 這學期沒有任何課開放成績是合法狀態，不可以映成失敗、也不能拿舊快取充數。
    await CacheStore.instance
        .write(MoodleRepository.courseGradesKey(), twoCourses());
    repo.next = MoodleCourseGradeList(
        semester: SemesterJson(year: '114', semester: '1'), courses: []);

    final result = await MoodleRepository.instance.getCourseGrades();

    expect(result, isA<Ok<MoodleCourseGradeList>>());
    expect(result.dataOrNull!.courses, isEmpty);
    expect((await cached())!.courses, isEmpty);
  });

  test('抓不到但有快取 → Stale(FetchFailed)，訊息是這條路徑的錯誤字串', () async {
    await CacheStore.instance
        .write(MoodleRepository.courseGradesKey(), twoCourses());
    repo.next = null;

    final result = await MoodleRepository.instance.getCourseGrades();

    expect(result, isA<Stale<MoodleCourseGradeList>>());
    final stale = result as Stale<MoodleCourseGradeList>;
    expect(stale.data.courses, hasLength(2));
    expect(stale.reason, isA<FetchFailed>());
    expect(stale.reason.message, R.current.getMoodleCourseGradesError);
    expect(ui.confirmCalls, 1, reason: '互動模式抓不到會先問要不要重試');
  });

  test('background: true 抓不到時不彈重試框，有快取就回 Stale', () async {
    await CacheStore.instance
        .write(MoodleRepository.courseGradesKey(), twoCourses());
    repo.next = null;

    final result =
        await MoodleRepository.instance.getCourseGrades(background: true);

    expect(result, isA<Stale<MoodleCourseGradeList>>());
    expect(ui.confirmCalls, 0);
    expect(auth.ensureInteractive, [false], reason: '進頁的第一趟不准開登入頁');
  });

  test('抓不到又沒快取 → Failed(FetchFailed)', () async {
    repo.next = null;

    final result = await MoodleRepository.instance.getCourseGrades();

    expect(result, isA<Failed<MoodleCourseGradeList>>());
    expect(
        (result as Failed<MoodleCourseGradeList>).reason, isA<FetchFailed>());
  });

  test('沒登入 → Failed(NotSignedIn)，不可重試也不 fetch', () async {
    AuthSession.instance =
        FakeAuthSession(ensureResults: [AuthFailure.notSignedIn]);

    final result = await MoodleRepository.instance.getCourseGrades();

    expect(result, isA<Failed<MoodleCourseGradeList>>());
    final reason = (result as Failed<MoodleCourseGradeList>).reason;
    expect(reason, isA<NotSignedIn>());
    expect(reason.retryable, isFalse);
    expect(repo.calls, 0);
  });

  test('快取 key 以 cache_ 開頭，登出時才會被一起清掉', () {
    expect(
        MoodleRepository.courseGradesKey().name, 'cache_moodle_course_grades');
    expect(MoodleRepository.courseGradesKey().id, 'current');
  });
}
