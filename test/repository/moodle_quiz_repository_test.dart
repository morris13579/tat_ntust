import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_best_grade.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_quiz_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// [MoodleRepository] 測驗那三條路徑：離線加上預先塞好的快取，不碰網路。
void main() {
  const courseId = 'CS3001701';
  const quizId = 5101;
  late TestStores stores;
  late RecordingUi ui;
  late FakeConnectivityProbe net;

  CacheKey<String> findIdKey() => CacheKey<String>(
        'cache_moodle_support',
        courseId,
        decode: (j) => j as String,
      );

  CacheKey<List<MoodleQuiz>> quizKey() => CacheKey<List<MoodleQuiz>>(
        'cache_moodle_quiz',
        courseId,
        decode: (json) => (json as List)
            .map(
                (e) => MoodleQuiz.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  CacheKey<List<MoodleQuizAttempt>> attemptsKey(int id) =>
      CacheKey<List<MoodleQuizAttempt>>(
        'cache_moodle_quiz_attempts',
        id.toString(),
        decode: (json) => (json as List)
            .map((e) =>
                MoodleQuizAttempt.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  CacheKey<MoodleQuizBestGrade> gradeKey(int id) =>
      CacheKey<MoodleQuizBestGrade>(
        'cache_moodle_quiz_grade',
        id.toString(),
        decode: decodeCachedQuizBestGrade,
      );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    stores = resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    ui = RecordingUi();
    TaskUiDelegate.instance = ui;
    net = FakeConnectivityProbe(online: false);
    ConnectivityProbe.instance = net;
    MoodleRepository.instance = MoodleRepository();
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
  });

  Future<void> seedQuizzes() async {
    await CacheStore.instance.write(findIdKey(), 'moodle-1');
    await CacheStore.instance.write(quizKey(), fixtureQuizzes());
  }

  group('getQuizzes', () {
    test('離線且有快取 → Stale(Offline)，兩份測驗', () async {
      await seedQuizzes();

      final result = await MoodleRepository.instance.getQuizzes(courseId);

      expect(result, isA<Stale<List<MoodleQuiz>>>());
      expect(result.dataOrNull!.map((q) => q.id), [5101, 5102]);
      expect((result as Stale).reason, isA<Offline>());
    });

    test('離線且沒有快取 → Failed(Offline)', () async {
      final result = await MoodleRepository.instance.getQuizzes(courseId);

      expect(result, isA<Failed<List<MoodleQuiz>>>());
      expect((result as Failed).reason, isA<Offline>());
    });

    test('快取存的是還原過的 name（清洗只寫在 connector）', () async {
      await seedQuizzes();

      final raw = await stores.plain.readString('cache_moodle_quiz');

      expect(raw, contains('期中考 & 小考'));
      expect(raw, isNot(contains('&amp;')));
      // 模型沒宣告的 key 不落地。
      expect(raw, isNot(contains('preferredbehaviour')));
      expect(raw, isNot(contains('reviewattempt')));
    });
  });

  group('getQuiz', () {
    test('從 Stale 清單裡挑到 → Stale(那一份)', () async {
      await seedQuizzes();

      final result = await MoodleRepository.instance.getQuiz(courseId, quizId);

      expect(result, isA<Stale<MoodleQuiz>>());
      expect(result.dataOrNull!.coursemodule, 94001);
      expect((result as Stale).reason, isA<Offline>());
    });

    test('清單裡沒有那個 id → Failed，原因沿用清單的（Offline）', () async {
      await seedQuizzes();

      final result = await MoodleRepository.instance.getQuiz(courseId, 9999);

      expect(result, isA<Failed<MoodleQuiz>>());
      expect((result as Failed).reason, isA<Offline>());
    });

    test('線上但課號解析不到 → Failed(UnsupportedCourse) 一路傳上來', () async {
      net.online = true;

      final result = await MoodleRepository.instance.getQuiz(courseId, quizId);

      expect(result, isA<Failed<MoodleQuiz>>());
      expect((result as Failed).reason, isA<UnsupportedCourse>());
      expect(ui.confirmCalls, 0, reason: '不可重試的原因不彈框');
    });
  });

  group('getQuizAttempts', () {
    test('離線且有快取 → Stale', () async {
      await CacheStore.instance
          .write(attemptsKey(quizId), fixtureAttempts('attempts_mixed'));

      final result = await MoodleRepository.instance.getQuizAttempts(quizId);

      expect(result, isA<Stale<List<MoodleQuizAttempt>>>());
      expect(result.dataOrNull!.map((a) => a.attempt), [1, 2, 3]);
    });

    test('離線且沒有快取 → Failed(Offline)', () async {
      final result = await MoodleRepository.instance.getQuizAttempts(quizId);

      expect(result, isA<Failed<List<MoodleQuizAttempt>>>());
      expect((result as Failed).reason, isA<Offline>());
    });
  });

  group('getQuizBestGrade', () {
    test('離線且有快取 → Stale', () async {
      await CacheStore.instance
          .write(gradeKey(quizId), fixtureBestGrade('best_grade'));

      final result = await MoodleRepository.instance.getQuizBestGrade(quizId);

      expect(result, isA<Stale<MoodleQuizBestGrade>>());
      expect(result.dataOrNull!.grade, 12.5);
      expect(result.dataOrNull!.gradetopass, 10);
    });

    test('離線且沒有快取 → Failed(Offline)', () async {
      final result = await MoodleRepository.instance.getQuizBestGrade(quizId);

      expect(result, isA<Failed<MoodleQuizBestGrade>>());
      expect((result as Failed).reason, isA<Offline>());
    });

    test('沒有 hasgrade 的舊 blob → 解碼拋、該筆被移除、回 Failed', () async {
      // 每個欄位都有 defaultValue，不主動拋的話會得到一頁永遠命中快取的
      // 「尚未有成績」。
      await CacheStore.instance.write<Map<String, dynamic>>(
        CacheKey<Map<String, dynamic>>(
            'cache_moodle_quiz_grade', quizId.toString(),
            decode: (j) => Map<String, dynamic>.from(j as Map)),
        {'warnings': <dynamic>[]},
      );

      final result = await MoodleRepository.instance.getQuizBestGrade(quizId);

      expect(result, isA<Failed<MoodleQuizBestGrade>>());
      expect(
        await CacheStore.instance.read(CacheKey<Map<String, dynamic>>(
            'cache_moodle_quiz_grade', quizId.toString(),
            decode: (j) => Map<String, dynamic>.from(j as Map))),
        isNull,
        reason: '壞掉的那一筆要被移除，否則每次進頁面都重讀重丟',
      );
    });

    test('decodeCachedQuizBestGrade 本身對缺 hasgrade 的 blob 拋 FormatException',
        () {
      expect(() => decodeCachedQuizBestGrade({'grade': 1}),
          throwsA(isA<FormatException>()));
      expect(decodeCachedQuizBestGrade({'hasgrade': false}).hasgrade, isFalse);
    });
  });

  group('快取 key', () {
    test('三個名稱都以 cache_ 開頭，登出時才會被清掉', () async {
      await seedQuizzes();
      await CacheStore.instance
          .write(attemptsKey(quizId), fixtureAttempts('attempts_mixed'));
      await CacheStore.instance
          .write(gradeKey(quizId), fixtureBestGrade('best_grade'));

      final keys = await stores.plain.keys();

      for (final k in [
        'cache_moodle_quiz',
        'cache_moodle_quiz_attempts',
        'cache_moodle_quiz_grade',
      ]) {
        expect(keys, contains(k));
        expect(k, startsWith('cache_'));
      }
    });
  });

  group('錯誤訊息', () {
    test('三條路徑各自帶自己的錯誤字串', () async {
      // 訊息由 R.current 提供，離線時會出現在 Failed 的 reason 上（Offline
      // 有自己的訊息）。key 存在由編譯器保證，這裡驗的是四句彼此不同：
      // 貼上去忘了改的那一句才是真正會發生的退化。
      expect({
        R.current.getMoodleQuizzesError,
        R.current.getMoodleQuizAttemptsError,
        R.current.getMoodleQuizBestGradeError,
        R.current.quizNotFound,
      }, hasLength(4));
    });
  });
}
