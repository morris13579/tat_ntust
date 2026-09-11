import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_get_grade_items.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// [MoodleRepository] 的行為。
///
/// 這些測試不需要網路：測試環境裡 `MoodleWebApiConnector` 的靜態方法一定會拋
/// （Dio 沒有初始化），而那正好走到「第一段解析失敗」與「第二段抓取失敗」
/// 兩條要驗的路徑。
void main() {
  const courseId = 'CS1234701';

  CacheKey<String> findIdKey() => CacheKey<String>(
        'cache_moodle_support',
        courseId,
        decode: (j) => j as String,
      );

  CacheKey<MoodleUserGradesEntity> scoreKey() =>
      CacheKey<MoodleUserGradesEntity>(
        'cache_moodle_score',
        courseId,
        decode: decodeCachedScore,
      );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    ConnectivityProbe.instance = FakeConnectivityProbe();
    MoodleRepository.instance = MoodleRepository();
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
  });

  group('第一段（課號 → Moodle 內部 id）失敗', () {
    test('仍然讀得到下游的資料快取，回 Stale', () async {
      // 第一段失敗不能連帶讓下游快取讀不到，否則離線的使用者看不到
      // 已經躺在硬碟上的成績。
      await CacheStore.instance
          .write(scoreKey(), MoodleUserGradesEntity(courseId: 42));

      final result = await MoodleRepository.instance.getCourseScore(courseId);

      expect(result, isA<Stale<MoodleUserGradesEntity>>());
      expect(result.dataOrNull!.courseId, 42);
      expect((result as Stale<MoodleUserGradesEntity>).reason,
          isA<UnsupportedCourse>());
    });

    test('沒有下游快取時回 Failed(UnsupportedCourse)', () async {
      final result = await MoodleRepository.instance.getCourseScore(courseId);

      expect(result, isA<Failed<MoodleUserGradesEntity>>());
      final reason = (result as Failed<MoodleUserGradesEntity>).reason;
      expect(reason, isA<UnsupportedCourse>());
      // 不可重試：UI 只會畫單鍵的「確定」。
      expect(reason.retryable, isFalse);
    });

    test('把對照表那一筆清掉，下次才會重新解析', () async {
      await CacheStore.instance.write(findIdKey(), 'stale-id');
      // 有命中就直接用，不會走到解析——所以先確認它真的是 read-through。
      expect(await CacheStore.instance.read(findIdKey()), 'stale-id');

      // 這一次會命中對照表、走第二段，第二段失敗不該動到對照表。
      await MoodleRepository.instance.getCourseScore(courseId);
      expect(await CacheStore.instance.read(findIdKey()), 'stale-id',
          reason: '第二段失敗不該讓對照表失效');

      await CacheStore.instance.removeEntry(findIdKey());
      await MoodleRepository.instance.getCourseScore(courseId);
      expect(await CacheStore.instance.read(findIdKey()), isNull);
    });
  });

  group('第二段（用內部 id 抓資料）失敗', () {
    test('原因是 FetchFailed 而不是 UnsupportedCourse', () async {
      // 對照表命中代表這門課在 Moodle 上找得到，失敗的是抓取本身。
      // 兩者的差別決定使用者看不看得到重試按鈕。
      await CacheStore.instance.write(findIdKey(), 'moodle-internal-id');

      final result = await MoodleRepository.instance.getCourseScore(courseId);

      expect(result, isA<Failed<MoodleUserGradesEntity>>());
      final reason = (result as Failed<MoodleUserGradesEntity>).reason;
      expect(reason, isNot(isA<UnsupportedCourse>()));
      expect(reason.retryable, isTrue);
    });
  });

  group('成員清單', () {
    test('空清單算失敗，不是「這門課沒有學生」', () async {
      // run() 只把 null 當失敗，所以 repository 要把空清單映成 null，
      // 否則空白畫面會被當成成功寫進快取。
      await CacheStore.instance.write(findIdKey(), 'moodle-internal-id');

      final result = await MoodleRepository.instance.getMembers(courseId);

      expect(result.hasData, isFalse);
    });
  });

  group('decodeCachedScore', () {
    test('舊格式（沒有 gradeitems）要拋，不能靜靜回空白', () {
      // MoodleUserGradesEntity 每個欄位都有 defaultValue，把舊 blob 丟進
      // fromJson 不會拋，只是 gradeitems 退回空清單——升級後第一次開成績頁
      // 一片空白，而且因為快取命中，重開 App 也還是空白。
      expect(
        () => decodeCachedScore({
          'courseid': 1,
          'userid': 2,
          'userfullname': 'x',
          'maxdepth': 3,
          'tabledata': const [],
        }),
        throwsFormatException,
      );
    });

    test('新格式照常解析', () {
      final entity = decodeCachedScore({'courseid': 7, 'gradeitems': const []});
      expect(entity.courseId, 7);
    });
  });
}
