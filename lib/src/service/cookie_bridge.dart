import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 兩套 cookie store 之間的唯一橋樑。
///
/// 這個 App 有兩個互不相通的 cookie store：Dio 的 `PersistCookieJar`，以及
/// 平台 WebView 的 store。哪一套是權威不是美學問題，是「誰改不動」的問題：
///
/// - `score_connector.dart` 的 HeadlessInAppWebView **全檔沒有任何 cookie
///   API**。要讓它改讀 Dio jar，就得替它發明一套注入機制。
/// - 反過來，所有互動式登入本來就跑在 WebView 裡，寫的就是平台 store。
///
/// 所以**平台 WebView store 是權威，Dio jar 是它的鏡像**。兩者確實會不同步：
/// 實機看過平台 store 的 SSO cookie 有效、課表載得出來，而 `NTUSTConnector`
/// 的 Dio 探針同時回報 `signedIn=false`。
class CookieBridge {
  const CookieBridge._();

  /// NTUST 各子系統共用的網域。
  ///
  /// **這是承重牆，不要收窄。** ssoam2、stuinfosys、i.ntust 是不同 host，
  /// 只有網域 cookie 能跨。改成逐 host 會**靜默**弄壞成績頁——
  /// `ScoreConnector` 拿不到 cookie 只會回 null，使用者看到的是通用錯誤。
  static const String _domain = ".ntust.edu.tw";

  /// 平台 WebView store 在 [url] 上有沒有 cookie，用來否決 Dio 探針。
  ///
  /// 不同步是雙向的，而反向（Dio jar 說已登入、平台 store 空的）會讓
  /// [NTUSTConnector.login] 跳過唯一會種平台 store 的登入。問不到時回 true，
  /// 「不否決」是保守的那一邊。
  static Future<bool> hasPlatformCookies({
    required WebUri url,
    CookieManager? manager,
  }) async {
    try {
      final cookies =
          await (manager ?? CookieManager.instance()).getCookies(url: url);
      return cookies.isNotEmpty;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return true;
    }
  }

  /// 把平台 WebView 上某個 URL 的 cookie 鏡射進 Dio jar。
  ///
  /// 回傳搬了幾顆。零代表 WebView 那邊也沒有，通常表示登入其實沒成功。
  static Future<int> mirrorToDio({
    required WebUri url,
    required CookieJar jar,
    CookieManager? manager,
  }) async {
    try {
      final cookies =
          await (manager ?? CookieManager.instance()).getCookies(url: url);
      final ioCookies = <io.Cookie>[];
      for (final c in cookies) {
        final k = io.Cookie(c.name, c.value)
          ..domain = _domain
          ..path = "/"
          // 保留來源旗標。整批重建時 secure 預設是 false，而
          // InAppWebViewPage.setCookies 之後又會以 isSecure: false 灌回
          // WebView——配上 android:usesCleartextTraffic 就等於允許這些已登入
          // 的 SSO cookie 走明文 http 送出。取不到時預設 true，寧可保守。
          ..secure = c.isSecure ?? true
          ..httpOnly = c.isHttpOnly ?? false;
        ioCookies.add(k);
      }
      if (ioCookies.isEmpty) return 0;

      // 先清空再寫入。同一顆 cookie 可能以 host-only 的形式留在 jar 裡，
      // 那會蓋過網域版本；整批取代最單純，而且權威在另一邊，jar 沒有獨有
      // 資料可以損失。
      await jar.deleteAll();
      await jar.saveFromResponse(url, ioCookies);
      Log.d("[cookie-bridge] 鏡射 ${ioCookies.length} 顆到 Dio jar");
      return ioCookies.length;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return 0;
    }
  }
}
