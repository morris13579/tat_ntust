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

/// 安靜的 Moodle 登入必須真的安靜。
///
/// Moodle 沒有 headless 路徑，`interactive: false` 不能只是少一個進度框，
/// 必須在開登入頁之前就停下來，否則背景預載會把登入頁蓋在課表上。
void main() {
  late _SpyGateway gateway;
  late AppAuthSession auth;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    gateway = _SpyGateway();
    InteractiveLoginGateway.instance = gateway;
    auth = AppAuthSession();
    CredentialsStore.instance
      ..setAccount('B10902000')
      ..setPassword('pw');
  });

  tearDown(() {
    InteractiveLoginGateway.instance =
        const UninstalledInteractiveLoginGateway();
  });

  test('interactive: false 不開 Moodle 登入頁，直接回 loginFailed', () async {
    final error =
        await auth.ensure({SystemId.moodleWebApi}, interactive: false);

    expect(gateway.moodleCalls, 0, reason: '這正是背景預載彈出登入頁的那一行');
    expect(error?.failure, AuthFailure.loginFailed);
  });

  test('tryEnsure 的 interactive 旗標會傳下去', () async {
    await auth.tryEnsure(SystemId.moodleWebApi, interactive: false);
    expect(gateway.moodleCalls, 0);
  });

  test('互動式的呼叫照樣開登入頁', () async {
    await auth.ensure({SystemId.moodleWebApi});
    expect(gateway.moodleCalls, 1);
  });

  test('沒有憑證時兩種模式都不開頁面', () async {
    CredentialsStore.instance
      ..setAccount('')
      ..setPassword('');

    expect((await auth.ensure({SystemId.moodleWebApi}))?.failure,
        AuthFailure.notSignedIn);
    expect(gateway.moodleCalls, 0);
  });
}
