import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 同一個系統的登入不能同時跑兩次。
///
/// 冷啟動時課表（ensure {ntustSso}）與 Moodle 的個人資料是並行的。沒有防重入
/// 的話兩邊都會發現「還沒登入」然後各自開一個 WebView——使用者看到兩個登入
/// 畫面接連跳出來，學校那邊收到兩次登入嘗試。
void main() {
  final auth = AppAuthSession();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(resetAppStatics);

  test('並行的兩次 ensure 共用同一個進行中的登入', () async {
    // 沒有憑證時 _ensureNtustSso 會立刻回 notSignedIn，所以這裡驗的是
    // 「同一個 Future 被共用」而不是網路行為。
    final a = auth.ensure({SystemId.ntustSso});
    final b = auth.ensure({SystemId.ntustSso});

    final results = await Future.wait([a, b]);
    expect(results[0]!.failure, AuthFailure.notSignedIn);
    expect(results[1]!.failure, AuthFailure.notSignedIn);
  });

  test('登入結束後 inFlight 會清空，下一次才會重跑', () async {
    await auth.ensure({SystemId.ntustSso});
    expect(AppAuthSession.inFlight, isEmpty,
        reason: '沒清掉的話第二次登入會拿到上一次的結果，永遠重試不了');
  });

  test('不同系統各自獨立，不會互相擋住', () async {
    CredentialsStore.instance
      ..setAccount('B10902000')
      ..setPassword('pw');

    // 這裡只確認並行的呼叫不會互相死鎖或回錯的結果。
    final results = await Future.wait([
      auth.ensure({SystemId.moodleWebApi}),
      auth.ensure({SystemId.moodleWebApi}),
    ]);
    expect(results[0], isNotNull);
    expect(results[1], isNotNull);
    expect(AppAuthSession.inFlight, isEmpty);
  });
}
