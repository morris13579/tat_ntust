import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/service/interactive_login_gateway.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 記下登入頁被開了幾次的閘道。兩個登入頁都回「使用者放棄」。
class _RecordingGateway implements InteractiveLoginGateway {
  int moodleCalls = 0;
  int ntustCalls = 0;

  @override
  Future<MoodleTokenEntity?> signInMoodle({
    required String account,
    required String password,
  }) async {
    moodleCalls++;
    return null;
  }

  @override
  Future<NtustInteractiveLoginResult?> signInNtust({
    required String account,
    required String password,
  }) async {
    ntustCalls++;
    return null;
  }
}

/// [AppAuthSession] 的行為。
void main() {
  /// **每個測試一個新實例。** SSO 的握手狀態是 AppAuthSession 的欄位，
  /// 共用實例會讓前一個測試設的 ssoReady 洩漏到下一個。
  late AppAuthSession auth;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    auth = AppAuthSession();
    AuthSession.instance = auth;
  });

  group('isSignedIn', () {
    test('帳號與密碼都有才算已登入', () {
      final repo = CredentialsStore.instance;
      expect(auth.isSignedIn, isFalse);

      repo.setAccount('B10902000');
      // 只檢查帳號非空會顯示成「已登入」，但沒有密碼，任何一次登入都會失敗。
      expect(auth.isSignedIn, isFalse, reason: '只有帳號不算');

      repo.setPassword('pw');
      expect(auth.isSignedIn, isTrue);
    });

    test('清掉憑證之後回 false', () async {
      CredentialsStore.instance
        ..setAccount('B10902000')
        ..setPassword('pw');
      expect(auth.isSignedIn, isTrue);

      await CredentialsStore.instance.clear();
      expect(auth.isSignedIn, isFalse);
    });
  });

  group('invalidate', () {
    void markAllLoggedIn() {
      auth.ssoReady = true;
      MoodleWebApiConnector.wsToken = 'a-token';
      MoodleWebApiConnector.wsToken = 'a-token';
    }

    test('ntustSso 只清 SSO，成績走的就是這一顆', () async {
      markAllLoggedIn();
      await auth.invalidate({SystemId.ntustSso});

      // 成績系統沒有自己的旗標可清：成績頁靠的就是 SSO cookie 這一顆。
      expect(auth.ssoReady, isFalse);
      // 沒有被要求的系統不受影響。
      expect((MoodleWebApiConnector.wsToken != null), isTrue);
    });

    test('兩個系統彼此獨立，讓一個失效不會動到另一個', () async {
      // 剩下的兩個系統之間零相依。
      markAllLoggedIn();
      await auth.invalidate({SystemId.moodleWebApi});
      expect(auth.ssoReady, isTrue, reason: 'Moodle 失效不該動到 SSO');

      markAllLoggedIn();
      await auth.invalidate({SystemId.ntustSso});
      expect((MoodleWebApiConnector.wsToken != null), isTrue,
          reason: 'SSO 失效不該動到 Moodle');
    });

    test('moodleWebApi 會同時清掉旗標與 token', () async {
      markAllLoggedIn();
      await auth.invalidate({SystemId.moodleWebApi});

      expect((MoodleWebApiConnector.wsToken != null), isFalse);
      // 旗標與 token 要一起清：只清旗標，下一次登入會拿同一顆失效的 token
      // 重跑；只清 token，登入檢查會因為旗標還在而直接放行，帶著 null token
      // 發請求。
      expect(MoodleWebApiConnector.wsToken, isNull);
      // Moodle **不**建立在 SSO 之上：wstoken 與 SSO cookie 是兩個獨立憑證。
      // 拿 wstoken 的過程雖然會經過 ssoam2，但那是 LoginMoodlePage 的 WebView
      // 自己完成的。
      expect(auth.ssoReady, isTrue, reason: 'Moodle 失效不該連帶作廢 SSO session');
    });

    test('一次讓全部失效', () async {
      markAllLoggedIn();
      await auth.invalidate(SystemId.values.toSet());

      expect(auth.ssoReady, isFalse);
      expect((MoodleWebApiConnector.wsToken != null), isFalse);
      expect(MoodleWebApiConnector.wsToken, isNull);
    });
  });

  group('ensure', () {
    // 這一組只涵蓋「不需要網路」的分支：已經登入的短路，以及沒有憑證時
    // 的立即失敗。真正發出請求的路徑只能實機驗。

    test('已經登入就直接回 null，不碰網路', () async {
      auth.ssoReady = true;
      expect(await auth.ensure({SystemId.ntustSso}), isNull);
    });

    test('沒有憑證時回 notSignedIn 而不是 loginFailed', () async {
      // 這個分別是有意義的：notSignedIn 不可重試，UI 應該畫登入按鈕；
      // loginFailed 可重試。run() 就是照這個分岔決定要不要彈重試框。
      final error = await auth.ensure({SystemId.ntustSso});
      expect(error, isNotNull);
      expect(error!.failure, AuthFailure.notSignedIn);
      expect(error.message, isNull);
    });

    test('空集合不需要任何登入：沒有憑證也回 null', () async {
      // `AppNoticeRepository` 用 `run(requires: const {})` 讓沒登入的使用者
      // 也看得到 App 公告，靠的就是這裡的迴圈跑零次。
      expect(await auth.ensure(const {}), isNull);
      expect(await auth.ensure(const {}, interactive: false), isNull);
    });

    test('Moodle 有 token 就算已登入', () async {
      MoodleWebApiConnector.wsToken = 'a-token';
      expect(await auth.ensure({SystemId.moodleWebApi}), isNull);
    });

    test('Moodle 沒有 token 也沒有憑證時回 notSignedIn', () async {
      final error = await auth.ensure({SystemId.moodleWebApi});
      expect(error!.failure, AuthFailure.notSignedIn);
    });

    test('兩邊都已就緒時一次要求兩個系統也回 null', () async {
      auth.ssoReady = true;
      MoodleWebApiConnector.wsToken = 'a-token';
      expect(await auth.ensure({SystemId.ntustSso, SystemId.moodleWebApi}),
          isNull);
    });

    test('安靜模式不開 Moodle 登入頁：有憑證、沒 token，interactive false 直接回 loginFailed',
        () async {
      // Moodle 沒有非互動的登入段，拿 wsToken 一定要開 WebView。背景預載
      //（run 的 background: true）走到這裡必須停下來，否則登入頁會蓋在
      // 使用者正在看的畫面上。
      CredentialsStore.instance
        ..setAccount('B10902000')
        ..setPassword('pw');
      MoodleWebApiConnector.wsToken = null;
      final gateway = _RecordingGateway();
      InteractiveLoginGateway.instance = gateway;

      final error =
          await auth.ensure({SystemId.moodleWebApi}, interactive: false);

      expect(error!.failure, AuthFailure.loginFailed);
      // 帶「尚未登入 Moodle」而不是空訊息：空訊息會被 LoginFailed 換成
      //「請登入」，跟畫面上給已登入者的「重新整理」鈕對不起來。
      expect(error.message, R.current.moodleNotSignedIn);
      expect(gateway.moodleCalls, 0, reason: '安靜模式不准開登入頁');
      expect(MoodleWebApiConnector.wsToken, isNull);
    });

    test('互動模式才會開 Moodle 登入頁；使用者放棄就是 loginFailed', () async {
      CredentialsStore.instance
        ..setAccount('B10902000')
        ..setPassword('pw');
      MoodleWebApiConnector.wsToken = null;
      final gateway = _RecordingGateway();
      InteractiveLoginGateway.instance = gateway;

      final error = await auth.ensure({SystemId.moodleWebApi});

      expect(gateway.moodleCalls, 1);
      expect(error!.failure, AuthFailure.loginFailed);
    });
  });

  group('tryEnsure', () {
    test('失敗不拋，讓呼叫端可以繼續做別的來源', () async {
      // 學期清單同時要成績與 Moodle，兩段各自 try——任一邊掛掉
      // 都不該讓另一邊的資料消失。
      await expectLater(auth.tryEnsure(SystemId.moodleWebApi), completes);
    });
  });
}
