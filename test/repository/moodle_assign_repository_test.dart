import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_assign_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// [MoodleRepository] 作業那三條路徑：離線加上預先塞好的快取，不碰網路。
void main() {
  const courseId = 'CS3001701';
  late TestStores stores;
  late RecordingUi ui;
  late FakeConnectivityProbe net;

  CacheKey<String> findIdKey() => CacheKey<String>(
        'cache_moodle_support',
        courseId,
        decode: (j) => j as String,
      );

  CacheKey<List<MoodleAssignment>> assignKey() =>
      CacheKey<List<MoodleAssignment>>(
        'cache_moodle_assign',
        courseId,
        decode: (json) => (json as List)
            .map((e) =>
                MoodleAssignment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  CacheKey<MoodleAssignSubmissionStatus> statusKey(int assignId) =>
      CacheKey<MoodleAssignSubmissionStatus>(
        'cache_moodle_assign_status',
        assignId.toString(),
        decode: (json) => MoodleAssignSubmissionStatus.fromJson(
            Map<String, dynamic>.from(json as Map)),
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

  Future<void> seedAssignments() async {
    await CacheStore.instance.write(findIdKey(), 'moodle-1');
    await CacheStore.instance.write(assignKey(), fixtureAssignments());
  }

  group('getAssignments', () {
    test('離線且有快取 → Stale(Offline)，兩份作業', () async {
      await seedAssignments();

      final result = await MoodleRepository.instance.getAssignments(courseId);

      expect(result, isA<Stale<List<MoodleAssignment>>>());
      expect(result.dataOrNull!.map((a) => a.id), [4101, 4102]);
      expect((result as Stale).reason, isA<Offline>());
    });

    test('離線且沒有快取 → Failed(Offline)', () async {
      final result = await MoodleRepository.instance.getAssignments(courseId);

      expect(result, isA<Failed<List<MoodleAssignment>>>());
      expect((result as Failed).reason, isA<Offline>());
    });

    test('快取裡的那一筆解不開 → 移除該筆、回 Failed，不拋', () async {
      // id 是字串：fromJson 會 TypeError，CacheStore.read 應該把它移除。
      await CacheStore.instance.write<List<dynamic>>(
        CacheKey<List<dynamic>>('cache_moodle_assign', courseId,
            decode: (j) => j as List),
        [
          {'id': 'abc', 'name': 'bad'}
        ],
      );

      final result = await MoodleRepository.instance.getAssignments(courseId);

      expect(result, isA<Failed<List<MoodleAssignment>>>());
      expect(
        await CacheStore.instance.read(CacheKey<List<dynamic>>(
            'cache_moodle_assign', courseId,
            decode: (j) => j as List)),
        isNull,
        reason: '壞掉的那一筆要被移除，否則每次進頁面都重讀重丟',
      );
    });
  });

  group('getAssignment', () {
    test('從 Stale 清單裡挑到 → Stale(那一份)', () async {
      await seedAssignments();

      final result =
          await MoodleRepository.instance.getAssignment(courseId, 4101);

      expect(result, isA<Stale<MoodleAssignment>>());
      expect(result.dataOrNull!.cmid, 93001);
      expect((result as Stale).reason, isA<Offline>());
    });

    test('清單裡沒有那個 id → Failed，原因沿用清單的（Offline）', () async {
      await seedAssignments();

      final result =
          await MoodleRepository.instance.getAssignment(courseId, 9999);

      expect(result, isA<Failed<MoodleAssignment>>());
      expect((result as Failed).reason, isA<Offline>());
    });

    test('線上但課號解析不到 → Failed(UnsupportedCourse) 一路傳上來', () async {
      // 對照表沒有這門課，connector 在測試環境一定失敗 → UnsupportedCourse。
      net.online = true;

      final result =
          await MoodleRepository.instance.getAssignment(courseId, 4101);

      expect(result, isA<Failed<MoodleAssignment>>());
      expect((result as Failed).reason, isA<UnsupportedCourse>());
      expect(ui.confirmCalls, 0, reason: '不可重試的原因不彈框');
    });
  });

  group('getSubmissionStatus', () {
    test('離線且有快取 → Stale', () async {
      await CacheStore.instance
          .write(statusKey(4101), fixtureStatus('status_graded'));

      final result = await MoodleRepository.instance.getSubmissionStatus(4101);

      expect(result, isA<Stale<MoodleAssignSubmissionStatus>>());
      expect(result.dataOrNull!.isGraded, isTrue);
      expect(result.dataOrNull!.feedback!.gradefordisplay,
          '85.00\u00a0/\u00a0100.00');
    });

    test('離線且沒有快取 → Failed(Offline)', () async {
      final result = await MoodleRepository.instance.getSubmissionStatus(4101);

      expect(result, isA<Failed<MoodleAssignSubmissionStatus>>());
      expect((result as Failed).reason, isA<Offline>());
    });

    test('快取裡是未清洗的 gradefordisplay → 讀回來時實體已還原', () async {
      // 清洗只寫在 connector，早於它寫進硬碟的 blob 還帶著 `&nbsp;`；
      // decode 要跟線上回應走同一條路徑，那些舊資料才不會直接畫上畫面。
      await CacheStore.instance
          .write(statusKey(4101), rawFixtureStatus('status_graded'));

      final result = await MoodleRepository.instance.getSubmissionStatus(4101);

      expect(result.dataOrNull!.feedback!.gradefordisplay,
          '85.00\u00a0/\u00a0100.00');
    });

    test('background: true → Stale 但不吐「載入快取」toast', () async {
      await CacheStore.instance
          .write(statusKey(4101), fixtureStatus('status_graded'));

      final result = await MoodleRepository.instance
          .getSubmissionStatus(4101, background: true);

      expect(result, isA<Stale<MoodleAssignSubmissionStatus>>());
      expect(ui.toasts, isEmpty, reason: '清單一次為 N 份作業抓狀態，各吐一則會把畫面刷滿');
    });

    test('background: false（詳情頁）→ 照常吐一則 toast', () async {
      await CacheStore.instance
          .write(statusKey(4101), fixtureStatus('status_graded'));

      await MoodleRepository.instance.getSubmissionStatus(4101);

      expect(ui.toasts, [R.current.loadingCache]);
    });
  });

  group('快取 key', () {
    test('兩個名稱都以 cache_ 開頭，登出時才會被清掉', () async {
      await CacheStore.instance.write(assignKey(), fixtureAssignments());
      await CacheStore.instance
          .write(statusKey(4101), fixtureStatus('status_none'));

      final keys = await stores.plain.keys();

      expect(keys, contains('cache_moodle_assign'));
      expect(keys, contains('cache_moodle_assign_status'));
      for (final k in ['cache_moodle_assign', 'cache_moodle_assign_status']) {
        expect(k, startsWith('cache_'));
      }
    });

    test('清單快取帶著繳交規則，但沒人讀的欄位仍然不落地', () async {
      await CacheStore.instance.write(assignKey(), fixtureAssignments());

      final raw = await stores.plain.readString('cache_moodle_assign');

      expect(raw, isNotNull);
      expect(raw, contains('"cmid":93001'));
      // 繳交入口要看 submissiondrafts 與 configs，所以它們現在有人讀了。
      expect(raw, contains('"submissiondrafts":1'));
      expect(raw, contains('configs'));
      expect(raw, isNot(contains('hidegrader')));
      expect(raw, isNot(contains('introfiles')));
      expect(raw, isNot(contains('gradingduedate')));
    });
  });
}
