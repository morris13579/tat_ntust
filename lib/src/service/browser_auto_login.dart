import 'dart:convert';

import 'package:flutter_app/src/service/ssoam2_login.dart';
import 'package:flutter_app/src/service/web_view_session.dart';

/// [BrowserAutoLogin.run] 的結果。
enum BrowserAutoLoginOutcome {
  /// 不是登入頁，什麼都沒做。
  notLoginPage,

  /// 已經送出；成功與否看接下來導到哪一頁。
  submitted,

  /// 代填被驗證碼擋下來，要使用者自己來。
  needsHuman,
}

/// App 內瀏覽器停在學校登入頁時代填帳密。Flutter 的 `InAppWebViewPage` 與原生版共用這一份。
class BrowserAutoLogin {
  const BrowserAutoLogin._();

  /// 舊的 NetIQ 登入頁。
  static const String legacyLoginUrl =
      "https://ssoam.ntust.edu.tw/nidp/app/login";

  static bool isLoginPage(Object? url) =>
      url != null &&
      (url.toString().startsWith(legacyLoginUrl) ||
          Ssoam2Login.isLoginPage(url));

  static Future<BrowserAutoLoginOutcome> run(
    WebViewDriver web,
    Object? url, {
    required String account,
    required String password,
  }) async {
    if (url != null && url.toString().startsWith(legacyLoginUrl)) {
      await web.evaluateJavascript(
          'document.getElementsByName("Ecom_User_ID")[0].value = ${jsonEncode(account)};');
      await web.evaluateJavascript(
          'document.getElementsByName("Ecom_Password")[0].value = ${jsonEncode(password)};');
      await web.evaluateJavascript(
          'document.getElementById("loginButton2").click();');
      return BrowserAutoLoginOutcome.submitted;
    }
    if (!Ssoam2Login.isLoginPage(url)) {
      return BrowserAutoLoginOutcome.notLoginPage;
    }
    final outcome = await Ssoam2Login.submit(web,
        account: account, password: password);
    return outcome == Ssoam2LoginOutcome.submitted
        ? BrowserAutoLoginOutcome.submitted
        : BrowserAutoLoginOutcome.needsHuman;
  }
}
