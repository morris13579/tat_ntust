import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/service/interactive_login_gateway.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 記錄有沒有人要求開可見登入頁。
class _SpyGateway implements InteractiveLoginGateway {
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

/// 站台明確拒絕過的帳密不可以一直重送。
///
/// 登入失敗時 ssoReady 仍是 false，而每一條 run() 都會各自再 ensure 一次，
/// 實測一次打錯密碼送出 6 次登入，而站台是「密碼錯誤 10 次鎖 15 分鐘」。
void main() {
  late AppAuthSession auth;
  late _SpyGateway gateway;

  const message = '帳號或密碼輸入錯誤。(The username or password is incorrect.)';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    auth = AppAuthSession();
    AuthSession.instance = auth;
    gateway = _SpyGateway();
    InteractiveLoginGateway.instance = gateway;
    CredentialsStore.instance
      ..setAccount('B10902000')
      ..setPassword('wrong-password');
  });

  tearDown(() {
    InteractiveLoginGateway.instance =
        const UninstalledInteractiveLoginGateway();
  });

  /// 模擬站台明確拒絕之後的狀態，不必打網路。
  void markRejected({String? account, String? password}) {
    final repo = CredentialsStore.instance;
    auth.rejectCredentials(
      AppAuthSession.credentialsFingerprint(
        account ?? repo.account,
        password ?? repo.password,
      ),
      message,
    );
  }

  test('被拒絕過的帳密，SSO 不再開登入頁', () async {
    markRejected();

    final error = await auth.ensure({SystemId.ntustSso});

    expect(error?.failure, AuthFailure.loginFailed);
    expect(gateway.ntustCalls, 0, reason: '每多開一次就多燒一次登入嘗試');
  });

  test('被拒絕過的帳密，Moodle 也不開登入頁——同一組憑證', () async {
    markRejected();

    final error = await auth.ensure({SystemId.moodleWebApi});

    expect(error?.failure, AuthFailure.loginFailed);
    expect(gateway.moodleCalls, 0);
  });

  test('invalidate 不會解除拒絕——「按重試」不該拿同一組錯帳密再送一次', () async {
    markRejected();

    await auth.invalidate({SystemId.ntustSso, SystemId.moodleWebApi});
    await auth.ensure({SystemId.ntustSso});

    expect(gateway.ntustCalls, 0);
  });

  test('改了密碼就解除——指紋跟著變', () async {
    markRejected();
    CredentialsStore.instance.setPassword('a-different-password');

    expect(
      AppAuthSession.credentialsFingerprint(CredentialsStore.instance.account,
          CredentialsStore.instance.password),
      isNot(auth.rejectedCredentials),
    );
  });

  test('改了帳號也解除', () {
    markRejected();
    CredentialsStore.instance.setAccount('B10902999');

    expect(
      AppAuthSession.credentialsFingerprint(CredentialsStore.instance.account,
          CredentialsStore.instance.password),
      isNot(auth.rejectedCredentials),
    );
  });

  test('沒有被拒絕過時，維持原本行為', () {
    expect(auth.rejectedCredentials, isNull);
  });

  test('站台拒絕的訊息會原樣帶給呼叫端', () async {
    // 錯誤對話框靠 message 在不在決定要不要畫「設定」鈕，見 AuthError。
    markRejected();

    final error = await auth.ensure({SystemId.ntustSso});

    expect(error?.message, message);
  });

  test('Moodle 那條也帶得回同一則訊息', () async {
    markRejected();

    final error = await auth.ensure({SystemId.moodleWebApi});

    expect(error?.message, message);
  });
}
