import 'package:flutter_app/main.dart' as app;
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/store/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/auth/app_auth_session.dart';

import 'helpers/reset_statics.dart';

/// `getInitialRoute` 必須分辨「沒有憑證」與「這次讀不到憑證」。
///
/// 兩者的 `isSignedIn` 都是 false，但該去的地方相反：
/// - absent：真的沒登入過 → 登入畫面。
/// - unavailable：安全儲存區暫時不可用（Android 備份還原、iOS 鎖定狀態下被
///   背景推播喚醒）→ **主畫面**。把「不知道」當成「已登出」會讓使用者白白
///   重打一次密碼，而 CredentialsLoadResult 這個三態當初就是為了避免這件事。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySecureStore secure;
  late InMemoryKeyValueStore plain;

  setUp(() {
    resetAppStatics();
    secure = InMemorySecureStore();
    plain = InMemoryKeyValueStore();
    CredentialsStore.instance = CredentialsStore(secure, plain);
    // 用真的 AppAuthSession，不是替身：這裡要驗的正是 isSignedIn 讀
    // CredentialsStore 的那條路，換成替身就什麼都沒驗到。
    AuthSession.instance = AppAuthSession();
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
  });

  test('已登入 → home', () async {
    CredentialsStore.instance.setAccount('B10902000');
    CredentialsStore.instance.setPassword('pw');
    await CredentialsStore.instance.save();

    expect(await app.getInitialRoute, 'home');
  });

  test('真的沒有憑證（absent）→ login', () async {
    expect(
        await CredentialsStore.instance.load(), CredentialsLoadResult.absent);

    expect(await app.getInitialRoute, 'login');
  });

  test('安全儲存區讀不到（unavailable）→ home，不是 login', () async {
    secure.throwOnRead = true;

    expect(await CredentialsStore.instance.load(),
        CredentialsLoadResult.unavailable);
    expect(CredentialsStore.instance.hasCredentials, isFalse,
        reason: '這正是舊碼把它誤判成「已登出」的原因');

    expect(await app.getInitialRoute, 'home',
        reason: '讀不到不等於沒登入。課表與成績都在硬碟上，看得到；真的需要'
            '憑證的操作會由 run() 照實報錯');
  });
}
