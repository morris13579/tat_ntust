import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/repository/retry.dart';
import 'package:flutter_app/src/repository/run.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

CacheKey<String> demoKey() =>
    CacheKey<String>('cache_demo', 'id', decode: (j) => j as String);

void main() {
  late FakeAuthSession auth;
  late RecordingUi ui;
  late FakeConnectivityProbe net;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    auth = FakeAuthSession();
    ui = RecordingUi();
    net = FakeConnectivityProbe();
    AuthSession.instance = auth;
    TaskUiDelegate.instance = ui;
    ConnectivityProbe.instance = net;
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  group('三態', () {
    test('fetch 成功回 Ok，並寫進快取', () async {
      final result = await run<String>(
        requires: {SystemId.ntustSso},
        cache: demoKey(),
        fetch: () async => 'fresh',
      );

      expect(result, isA<Ok<String>>());
      expect((result as Ok<String>).data, 'fresh');
      expect(await CacheStore.instance.read(demoKey()), 'fresh');
      expect(auth.ensureCalls.single, {SystemId.ntustSso});
    });

    test('fetch 回 null、使用者放棄、有快取 → Stale', () async {
      await CacheStore.instance.write(demoKey(), 'old');

      final result = await run<String>(
        requires: {SystemId.ntustSso},
        cache: demoKey(),
        fetch: () async => null,
      );

      expect(result, isA<Stale<String>>());
      final stale = result as Stale<String>;
      expect(stale.data, 'old');
      expect(stale.reason, isA<FetchFailed>());
      // 這條路徑要吐一則「載入快取」的 toast。
      expect(ui.toasts, hasLength(1));
    });

    test('background: true 時 Stale 不吐 loadingCache toast', () async {
      // 背景取資料時使用者沒按任何東西；作業清單一次為 N 份作業抓狀態，
      // 各吐一則會把畫面刷滿。畫面自己用 Stale 標示。
      await CacheStore.instance.write(demoKey(), 'old');
      net.online = false;

      final result = await run<String>(
        requires: {SystemId.ntustSso},
        cache: demoKey(),
        background: true,
        fetch: () async => 'fresh',
      );

      expect(result, isA<Stale<String>>());
      expect(ui.toasts, isEmpty);
    });

    test('fetch 回 null、使用者放棄、沒有快取 → Failed', () async {
      final result = await run<String>(
        requires: {SystemId.ntustSso},
        cache: demoKey(),
        fetch: () async => null,
      );

      expect(result, isA<Failed<String>>());
      expect((result as Failed<String>).reason, isA<FetchFailed>());
      expect(ui.toasts, isEmpty);
    });

    test('完全沒設定快取時，失敗一律是 Failed', () async {
      final result = await run<String>(
        requires: const {},
        fetch: () async => null,
      );

      expect(result, isA<Failed<String>>());
    });
  });

  group('離線', () {
    test('斷網且有快取 → Stale(Offline)，完全不呼叫 fetch 與 ensure', () async {
      await CacheStore.instance.write(demoKey(), 'old');
      net.online = false;
      var fetched = false;

      final result = await run<String>(
        requires: {SystemId.ntustSso},
        cache: demoKey(),
        fetch: () async {
          fetched = true;
          return 'fresh';
        },
      );

      expect(result, isA<Stale<String>>());
      expect((result as Stale<String>).reason, isA<Offline>());
      expect(fetched, isFalse, reason: '斷網就不該打網路');
      expect(auth.ensureCalls, isEmpty, reason: '斷網就不該嘗試登入');
      expect(ui.confirmCalls, 0, reason: '斷網不彈重試框，與今天一致');
    });

    test('斷網且沒有快取 → Failed(Offline)', () async {
      net.online = false;

      final result = await run<String>(
        requires: {SystemId.ntustSso},
        cache: demoKey(),
        fetch: () async => 'fresh',
      );

      expect(result, isA<Failed<String>>());
      expect((result as Failed<String>).reason, isA<Offline>());
    });

    test('fetch 途中斷線，例外會被重新分類成 Offline 而不是 FetchFailed', () async {
      final result = await run<String>(
        requires: const {},
        retry: RetryPolicy.none,
        fetch: () async {
          net.online = false;
          throw Exception('socket closed');
        },
      );

      expect((result as Failed<String>).reason, isA<Offline>(),
          reason: '彈框前要再探一次連線，這個診斷要保留');
    });
  });

  group('重試迴圈', () {
    test('使用者按重試 → invalidate 之後重跑，第二次成功', () async {
      ui = RecordingUi(decisions: [RetryDecision.retry]);
      TaskUiDelegate.instance = ui;
      var attempts = 0;

      final result = await run<String>(
        requires: {SystemId.ntustSso},
        fetch: () async {
          attempts++;
          return attempts == 1 ? null : 'fresh';
        },
      );

      expect(result, isA<Ok<String>>());
      expect(attempts, 2);
      // 重試前必須讓相依的系統失效，否則第二輪會帶著同一份死憑證重跑。
      expect(auth.invalidateCalls.single, {SystemId.ntustSso});
      expect(auth.ensureCalls, hasLength(2));
    });

    test('登入失敗也走同一個重試迴圈', () async {
      auth = FakeAuthSession(ensureResults: [AuthFailure.loginFailed]);
      AuthSession.instance = auth;
      ui = RecordingUi(decisions: [RetryDecision.retry]);
      TaskUiDelegate.instance = ui;
      var fetched = 0;

      final result = await run<String>(
        requires: {SystemId.moodleWebApi},
        fetch: () async {
          fetched++;
          return 'fresh';
        },
      );

      expect(result, isA<Ok<String>>());
      expect(fetched, 1, reason: '第一輪登入就失敗，fetch 不該被呼叫');
      expect(auth.invalidateCalls.single, {SystemId.moodleWebApi});
      expect(ui.confirmCalls, 1);
    });

    test('登入失敗且使用者放棄 → 回退到快取', () async {
      auth = FakeAuthSession(ensureResults: [AuthFailure.loginFailed]);
      AuthSession.instance = auth;
      await CacheStore.instance.write(demoKey(), 'old');

      final result = await run<String>(
        requires: {SystemId.moodleWebApi},
        cache: demoKey(),
        fetch: () async => 'fresh',
      );

      expect(result, isA<Stale<String>>());
      expect((result as Stale<String>).reason, isA<LoginFailed>());
    });

    test('RetryPolicy.none 立即回退，不彈對話框', () async {
      await CacheStore.instance.write(demoKey(), 'old');

      final result = await run<String>(
        requires: const {},
        cache: demoKey(),
        retry: RetryPolicy.none,
        fetch: () async => null,
      );

      expect(result, isA<Stale<String>>());
      expect(ui.confirmCalls, 0);
      expect(auth.invalidateCalls, isEmpty);
    });

    test('reason.retryable 為 false 時跳過對話框', () async {
      final result = await run<String>(
        requires: const {},
        fetch: () async => throw const TaskFailure(UnsupportedCourse()),
      );

      expect(result, isA<Failed<String>>());
      expect((result as Failed<String>).reason, isA<UnsupportedCourse>());
      expect(ui.confirmCalls, 0, reason: '不支援的課程重試也沒用，今天顯示的是單鍵框');
    });

    test('NotSignedIn 不可重試，直接回 Failed 讓 UI 畫登入鈕', () async {
      auth = FakeAuthSession(ensureResults: [AuthFailure.notSignedIn]);
      AuthSession.instance = auth;

      final result = await run<String>(
        requires: {SystemId.ntustSso},
        fetch: () async => 'fresh',
      );

      expect((result as Failed<String>).reason, isA<NotSignedIn>());
      expect((result).reason.retryable, isFalse);
      expect(ui.confirmCalls, 0);
      expect(auth.invalidateCalls, isEmpty);
    });

    test('fetch 丟 TaskFailure 時原樣取出 reason', () async {
      final result = await run<String>(
        requires: const {},
        retry: RetryPolicy.none,
        fetch: () async => throw const TaskFailure(LoginFailed('自訂訊息')),
      );

      final reason = (result as Failed<String>).reason;
      expect(reason, isA<LoginFailed>());
      expect(reason.message, '自訂訊息');
    });
  });

  group('cacheFirst', () {
    test('命中時零網路、零登入、零 fetch', () async {
      await CacheStore.instance.write(demoKey(), 'cached-id');
      var fetched = false;

      final result = await run<String>(
        requires: {SystemId.moodleWebApi},
        cache: demoKey(),
        cacheFirst: true,
        fetch: () async {
          fetched = true;
          return 'fresh';
        },
      );

      expect(result, isA<Ok<String>>());
      expect((result as Ok<String>).data, 'cached-id');
      expect(fetched, isFalse);
      expect(auth.ensureCalls, isEmpty);
      expect(net.calls, 0, reason: 'cacheFirst 命中連連線都不用探');
    });

    test('沒命中時照常走完整流程', () async {
      final result = await run<String>(
        requires: {SystemId.moodleWebApi},
        cache: demoKey(),
        cacheFirst: true,
        fetch: () async => 'fresh',
      );

      expect((result as Ok<String>).data, 'fresh');
      expect(auth.ensureCalls, hasLength(1));
    });

    test('預設不是 cacheFirst：有快取也照樣打網路，畫面不會先閃舊資料', () async {
      await CacheStore.instance.write(demoKey(), 'old');

      final result = await run<String>(
        requires: const {},
        cache: demoKey(),
        fetch: () async => 'fresh',
      );

      expect((result as Ok<String>).data, 'fresh');
    });
  });

  group('optional 與進度框', () {
    test('optional 的系統以 tryEnsure 登入，失敗不影響結果', () async {
      final result = await run<String>(
        requires: {SystemId.ntustSso},
        optional: {SystemId.moodleWebApi},
        fetch: () async => 'fresh',
      );

      expect(result, isA<Ok<String>>());
      expect(auth.tryEnsureCalls, [SystemId.moodleWebApi]);
    });

    test('進度框成對出現，fetch 拋例外也一定會關掉', () async {
      await run<String>(
        requires: const {},
        progressMessage: '載入中',
        retry: RetryPolicy.none,
        fetch: () async => throw Exception('boom'),
      );

      expect(ui.progressShown, ['載入中']);
      // 只能 dismiss 自己拿到的 handle：關掉別人的遮罩會讓並行分頁看起來
      // 也載完了。
      expect(ui.dismissCalls, 1,
          reason: '取代今天手動配對的 onStart/onEnd，try/finally 保證關掉');
    });

    test('沒給 progressMessage 就完全不碰進度框', () async {
      await run<String>(requires: const {}, fetch: () async => 'x');

      expect(ui.progressShown, isEmpty);
      expect(ui.dismissCalls, 0);
    });
  });

  group('Result 的便利存取', () {
    test('hasData 與 dataOrNull', () {
      expect(const Ok<String>('a').hasData, isTrue);
      expect(const Ok<String>('a').dataOrNull, 'a');
      expect(const Stale<String>('b', Offline()).hasData, isTrue);
      expect(const Stale<String>('b', Offline()).dataOrNull, 'b');
      expect(const Failed<String>(Offline()).hasData, isFalse);
      expect(const Failed<String>(Offline()).dataOrNull, isNull);
    });
  });

  group('登入失敗的訊息要傳到對話框', () {
    test('站台說了原因時，訊息與「去設定」的出口都要在', () async {
      // 站台明確拒絕憑證（帳密錯）時，對話框除了重試還要給一顆通往登入設定
      // 的按鈕，並顯示 AuthError.message；丟掉它的話使用者只看得到一句通用
      // 訊息，而且沒有出口。
      auth = FakeAuthSession(ensureResults: [AuthFailure.loginFailed]);
      auth.ensureError =
          const AuthError(AuthFailure.loginFailed, message: '帳號或密碼錯誤');
      AuthSession.instance = auth;

      await run<String>(
        requires: {SystemId.ntustSso},
        fetch: () async => 'x',
      );

      expect(ui.lastParameter?.desc, '帳號或密碼錯誤');
      expect(ui.lastParameter?.offerLoginScreen, isTrue);
    });

    test('沒有原因時只給重試，不給登入出口', () async {
      // 一般的登入失敗（逾時、站台掛掉）多一顆通往登入頁的按鈕，反而讓人
      // 以為是自己帳號有問題。
      auth = FakeAuthSession(ensureResults: [AuthFailure.loginFailed]);
      AuthSession.instance = auth;

      await run<String>(
        requires: {SystemId.ntustSso},
        fetch: () async => 'x',
      );

      expect(ui.lastParameter?.offerLoginScreen, isFalse);
    });
  });
}
