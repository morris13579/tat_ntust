import 'dart:async';

import 'package:html/parser.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/service/cookie_bridge.dart';
import 'package:flutter_app/src/service/ssoam2_login.dart';
import 'package:flutter_app/src/service/ssoam2_headless_login.dart';
import 'package:flutter_app/src/enum/ntust_login_status.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/model/ntust/ap_tree_json.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:html/dom.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class NTUSTConnector {
  static const String host = "https://i.ntust.edu.tw";
  static const String subSystemTWUrl = "$host/student";
  static const String ntustLoginUrl = "https://ssoam2.ntust.edu.tw/";

  static const String subSystemENUrl = "$host/EN/student";

  /// 不需要真人的 NTUST SSO 登入。
  ///
  /// 兩段：先用 Dio 探針問「現在登入了沒有」，沒有的話在 headless WebView
  /// 裡跑登入表單。兩段都失敗才由呼叫端升級到可見登入頁。
  ///
  /// 回傳的 map 有兩個鍵：`status` 一定有；`message` 只在**站台明確拒絕**
  /// （帳號密碼錯）時才有。有 message 就代表再開一次可見登入頁也是同樣結果，
  /// 呼叫端應該直接把訊息秀給使用者，不要再燒一次登入嘗試。
  ///
  /// **第二段不能改回純 Dio 的 POST**：它帶不了 `cf-turnstile-response`，
  /// 而且 cookie 只落在 Dio jar，成績頁讀的卻是平台 WebView store。它成功
  /// 比失敗更糟——成功就會跳過唯一會種平台 store 的 WebView，使用者被鎖在
  /// 「登入永遠成功、成績永遠失敗」。
  static Future<Map<String, dynamic>> login(
      String account, String password) async {
    try {
      // 第一段：Dio 探針。PersistCookieJar 會落磁碟，所以暖啟動多半在這裡
      // 就結束，不必開任何 WebView。誤判的後果是良性的（多跑一次登入）。
      final parameter = ConnectorParameter(ntustLoginUrl);
      final ntustLoginPage = await Connector.getDataByGet(parameter);
      final signedIn = Ssoam2Login.isSignedInPage(ntustLoginPage);
      // 探針說登入了還不夠，平台 store 也要有 cookie。Dio jar 的 session
      // cookie 跨啟動存活、iOS 的 WKWebView 不保證，兩者不同步時會跳過唯一
      // 會種平台 store 的 headless 登入，結果是「登入永遠成功、成績永遠失敗」。
      final platformSignedIn =
          await CookieBridge.hasPlatformCookies(url: WebUri(ntustLoginUrl));
      Log.d("[sso-probe] len=${ntustLoginPage.length} signedIn=$signedIn "
          "platformCookies=$platformSignedIn");
      if (signedIn && platformSignedIn) {
        return {"status": NTUSTLoginStatus.success};
      }

      // 第二段：headless WebView。它能執行 Turnstile 的 JS，而且 cookie
      // 落在平台 store——與可見登入頁、與成績頁讀的是同一套。
      final outcome = await Ssoam2HeadlessLogin.attempt(
        account: account,
        password: password,
        jar: DioConnector.instance.cookiesManager,
      );
      Log.d("[sso-headless] outcome=$outcome");
      switch (outcome) {
        case Ssoam2HeadlessOutcome.success:
          return {"status": NTUSTLoginStatus.success};
        case Ssoam2HeadlessOutcome.rejected:
          return {
            "status": NTUSTLoginStatus.fail,
            "message": R.current.accountPasswordError,
          };
        case Ssoam2HeadlessOutcome.needsHuman:
        case Ssoam2HeadlessOutcome.failed:
          break;
      }
    } catch (e, stack) {
      Log.eWithStack(e, stack);
    }
    return {"status": NTUSTLoginStatus.fail};
  }

  static Future<List<APTreeJson>?> getSubSystem() async {
    String result;
    Document tagNode;
    Element? node;
    try {
      String subSystemUrl = (LanguageUtils.getLangIndex() == LangEnum.zh)
          ? subSystemTWUrl
          : subSystemENUrl;
      ConnectorParameter parameter = ConnectorParameter(subSystemUrl);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      node = tagNode.getElementById("service");
      if (node == null) {
        // 拿得到頁面但找不到 service 節點，代表 session 在伺服器端過期或
        // 學校改了版面。這不是「真的沒有子系統」，必須讓呼叫端看得出差別。
        Log.e("getSubSystem: #service node not found");
        return null;
      }

      List<APTreeJson> resList = [];

      var serviceFunctions = node.children
          .where((element) => element.id.contains("service"))
          .toList();
      for (var i in serviceFunctions) {
        List<APListJson> apList = [];
        var serviceId = i.id;

        if (serviceId == "commonly-used-service") {
          continue;
        }

        var links = i.getElementsByTagName("a");

        for (var link in links) {
          apList.add(APListJson(
              name: link.text,
              url: link.attributes["href"] ?? "",
              type: "link"));
        }

        var tree = APTreeJson(serviceId, apList);
        resList.add(tree);
      }
      return resList;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static const String calendarHost = "https://www.academic.ntust.edu.tw";
  static const String calendarPageUrl =
      "$calendarHost/p/404-1048-78935.php?Lang=zh-tw";

  /// 從教務處行事曆頁面挑出各學年度的 .ics 下載連結。
  ///
  /// 抽成純函式是為了讓下面三個 DOM 假設能被 fixture golden 守住——學校改版
  /// 時是這幾行先壞，而不是等使用者回報「行事曆下載失敗」：
  ///
  /// 1. 第 2 個 `.meditor` 區塊才是內文（第 1 個是頁首導覽、第 3 個是頁尾）。
  /// 2. 該區塊裡有兩個 ul，前面是 .xlsx、**最後一個**才是 .ics，故取 `.last`。
  /// 3. li 的文字是「115學年度行事曆(ics檔案)」，選單只要 `(` 之前那段。
  ///
  /// 含 google 的那一項是 Google Calendar 訂閱連結不是 .ics 檔，要跳過。
  ///
  /// href 本身就以 "/" 開頭，接上 host 會產生 `https://.../\/var/file/...`
  /// 的雙斜線。這是刻意保留的：實測伺服器照樣回 200，改掉會連帶動到既有
  /// 下載檔的檔名判斷。
  static Map<String, String> parseCalendarLinks(String html, String host) {
    final Map<String, String> selects = {};
    final Document tagNode = parse(html);
    final List<Element> nodes = tagNode.getElementsByClassName("meditor");
    final Element node = nodes[1].getElementsByTagName("ul").last;
    for (var i in node.getElementsByTagName("li")) {
      String url = i.getElementsByTagName("a").first.attributes["href"]!;
      if (i.text.contains("google")) {
        continue;
      }
      String key = i.text.split("(").first;
      selects[key] = "$host/$url";
    }
    return selects;
  }

  static Future<Map<String, String>?> getCalendarUrl() async {
    try {
      ConnectorParameter parameter = ConnectorParameter(calendarPageUrl);
      final String result = await Connector.getDataByGet(parameter);
      return parseCalendarLinks(result, calendarHost);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }
}
