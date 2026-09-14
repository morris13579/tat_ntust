import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/service/browser_auto_login.dart';
import 'package:flutter_app/src/service/native_web_session.dart';
import 'package:flutter_app/src/store/model.dart';

/// 原生版 App 內瀏覽器停在學校登入頁時代填帳密，判準與流程在 [BrowserAutoLogin]。
class BrowserBridge implements TatBrowserApi {
  const BrowserBridge();

  static void install() => TatBrowserApi.setUp(const BrowserBridge());

  @override
  int reserveSession() => NativeWebSessions.instance.reserveId();

  @override
  bool isLoginPage(String url) => BrowserAutoLogin.isLoginPage(url);

  @override
  Future<BrowserLoginOutcome> autoLogin(int sessionId, String url) async {
    final outcome = await BrowserAutoLogin.run(
      NativeWebSessions.instance.driver(sessionId),
      url,
      account: Model.instance.getAccount(),
      password: Model.instance.getPassword(),
    );
    return BrowserLoginOutcome.values.byName(outcome.name);
  }
}
