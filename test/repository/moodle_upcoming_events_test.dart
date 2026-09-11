import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/R.dart';
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
  List<MoodleActionEvent>? next;
  int calls = 0;

  @override
  Future<List<MoodleActionEvent>?> fetchActionEvents() async {
    calls++;
    return next;
  }
}

/// [MoodleRepository.getUpcomingEvents] 的行為：三態、快取、背景模式。
void main() {
  late _FakeRepo repo;
  late FakeAuthSession auth;
  late RecordingUi ui;
  late FakeConnectivityProbe net;

  List<MoodleActionEvent> twoEvents() => [
        MoodleActionEvent(id: 1, name: '作業一 到期', timesort: 1757952000),
        MoodleActionEvent(id: 2, name: '小考一 關閉', timesort: 1758038400),
      ];

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

  Future<List<MoodleActionEvent>?> cached() =>
      CacheStore.instance.read(MoodleRepository.upcomingEventsKey());

  test('抓到就回 Ok，並寫進快取', () async {
    repo.next = twoEvents();

    final result = await MoodleRepository.instance.getUpcomingEvents();

    expect(result, isA<Ok<List<MoodleActionEvent>>>());
    expect(result.dataOrNull!.map((e) => e.id), [1, 2]);
    expect((await cached())!.map((e) => e.id), [1, 2]);
    expect(repo.calls, 1);
  });

  test('空清單是合法結果：Ok 且快取裡是空的', () async {
    // 沒有作業的學生不該看到錯誤頁，也不該被拿快取裡的舊清單騙。
    await CacheStore.instance
        .write(MoodleRepository.upcomingEventsKey(), twoEvents());
    repo.next = [];

    final result = await MoodleRepository.instance.getUpcomingEvents();

    expect(result, isA<Ok<List<MoodleActionEvent>>>());
    expect(result.hasData, isTrue);
    expect(result.dataOrNull, isEmpty);
    expect(await cached(), isEmpty);
  });

  test('抓不到且有快取 → Stale(FetchFailed)，訊息是這條路徑的錯誤字串', () async {
    await CacheStore.instance
        .write(MoodleRepository.upcomingEventsKey(), twoEvents());
    repo.next = null;

    final result = await MoodleRepository.instance.getUpcomingEvents();

    expect(result, isA<Stale<List<MoodleActionEvent>>>());
    final stale = result as Stale<List<MoodleActionEvent>>;
    expect(stale.data.map((e) => e.id), [1, 2]);
    expect(stale.reason, isA<FetchFailed>());
    expect(stale.reason.message, R.current.getUpcomingEventsError);
    // 互動模式：抓不到會先問使用者要不要重試。
    expect(ui.confirmCalls, 1);
  });

  test('抓不到也沒有快取 → Failed(FetchFailed)', () async {
    repo.next = null;

    final result = await MoodleRepository.instance.getUpcomingEvents();

    expect(result, isA<Failed<List<MoodleActionEvent>>>());
    expect(
        (result as Failed<List<MoodleActionEvent>>).reason, isA<FetchFailed>());
  });

  group('background', () {
    test('以 interactive: false 登入，登入失敗不彈框、不 fetch', () async {
      auth = FakeAuthSession(ensureResults: [AuthFailure.loginFailed]);
      AuthSession.instance = auth;

      final result =
          await MoodleRepository.instance.getUpcomingEvents(background: true);

      expect(auth.ensureInteractive, [false], reason: '背景預載不准開登入頁');
      expect(result, isA<Failed<List<MoodleActionEvent>>>());
      expect((result as Failed<List<MoodleActionEvent>>).reason,
          isA<LoginFailed>());
      expect(ui.confirmCalls, 0, reason: 'retry: none，不彈重試框');
      expect(repo.calls, 0);
      expect(ui.progressShown, isEmpty);
    });

    test('背景模式抓不到也不彈框，有快取就回 Stale', () async {
      await CacheStore.instance
          .write(MoodleRepository.upcomingEventsKey(), twoEvents());
      repo.next = null;

      final result =
          await MoodleRepository.instance.getUpcomingEvents(background: true);

      expect(result, isA<Stale<List<MoodleActionEvent>>>());
      expect(ui.confirmCalls, 0);
    });

    test('互動模式（重新整理鍵）以 interactive: true 登入', () async {
      repo.next = twoEvents();

      await MoodleRepository.instance.getUpcomingEvents();

      expect(auth.ensureInteractive, [true]);
      expect(auth.ensureCalls.single, {SystemId.moodleWebApi});
    });
  });

  test('沒有憑證 → Failed(NotSignedIn)，不可重試', () async {
    auth = FakeAuthSession(ensureResults: [AuthFailure.notSignedIn]);
    AuthSession.instance = auth;

    final result = await MoodleRepository.instance.getUpcomingEvents();

    expect(result, isA<Failed<List<MoodleActionEvent>>>());
    final reason = (result as Failed<List<MoodleActionEvent>>).reason;
    expect(reason, isA<NotSignedIn>());
    expect(reason.retryable, isFalse);
    expect(ui.confirmCalls, 0);
    expect(repo.calls, 0);
  });

  test('離線且有快取 → Stale(Offline)，完全不 fetch', () async {
    await CacheStore.instance
        .write(MoodleRepository.upcomingEventsKey(), twoEvents());
    net.online = false;

    final result = await MoodleRepository.instance.getUpcomingEvents();

    expect(result, isA<Stale<List<MoodleActionEvent>>>());
    expect((result as Stale<List<MoodleActionEvent>>).reason, isA<Offline>());
    expect(repo.calls, 0);
    expect(auth.ensureCalls, isEmpty);
  });

  test('快取 key 以 cache_ 開頭，登出時才會被一起清掉', () {
    expect(MoodleRepository.upcomingEventsKey().name,
        'cache_moodle_action_events');
    expect(MoodleRepository.upcomingEventsKey().id, 'all');
  });
}
