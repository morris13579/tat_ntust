import 'dart:async';
import 'dart:ui';

import 'package:cookie_jar/cookie_jar.dart';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/service/cookie_bridge.dart';
import 'package:flutter_app/src/service/ssoam2_login.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 不需要真人的 ssoam2 登入：在 headless WebView 裡跑 [Ssoam2Login]。
///
/// **為什麼是 WebView 而不是 Dio。** 純 Dio 的 POST 有兩個結構性問題：
/// 帶不了 `cf-turnstile-response`（Turnstile 的 token 只有在頁面裡執行 JS
/// 才拿得到），以及 cookie 落在 Dio jar——而成績頁的 headless WebView 讀的
/// 是**平台 cookie store**，兩者不互通。實機確認那條路一律回 non-200。
///
/// headless WebView 兩個問題都沒有：它能執行 Turnstile 的 JS，而且它寫的
/// 就是平台 store——與可見登入頁、與成績頁讀的是同一套。
///
/// **失敗就退回可見登入頁**（`InteractiveLoginGateway`），最壞情況是使用者
/// 看到登入頁，自己操作。
class Ssoam2HeadlessLogin {
  const Ssoam2HeadlessLogin._();

  /// 送出之前的上限。
  ///
  /// 這一段是「載入頁面、確認要不要填表、等挑戰出現」。它失敗代表我們根本
  /// 沒有嘗試登入，交給可見登入頁沒有任何損失。
  static const Duration _budgetBeforeSubmit = Duration(seconds: 12);

  /// 送出之後的上限。
  ///
  /// **刻意比前半寬鬆很多。** 表單送出成功但 SSO 的轉址鏈還沒跑完就撞到
  /// 前半的預算，會回報 failed 並彈出一個顯示「已經登入」的登入頁——登入
  /// 其實成功了，是我們先放棄的。一旦送出就已經在伺服器端留下一次登入，
  /// 這時多等幾秒遠比那樣好。
  static const Duration _budgetAfterSubmit = Duration(seconds: 25);

  /// [jar] 是要被鏡射的目標（Dio 的 cookie jar）。由呼叫端傳進來而不是自己
  /// 去 `DioConnector.instance` 拿：反向 import connector 是 `tool/deps.py`
  /// 會擋下來的上行邊，而且「怎麼登入」不該知道 jar 是從哪裡來的。
  static Future<Ssoam2HeadlessOutcome> attempt({
    required String account,
    required String password,
    required CookieJar jar,
  }) async {
    final completer = Completer<Ssoam2HeadlessOutcome>();
    HeadlessInAppWebView? webView;
    // 逾時之後還要問一次頁面狀態，所以留住最後一次拿到的 controller。
    InAppWebViewController? lastController;
    // 只導一次，避免站台把我們導回根路徑時無限來回。
    var navigatedToForm = false;
    // 表單送出去了沒有。決定用哪一段預算，也決定逾時要怎麼收尾。
    var submitted = false;

    void finish(Ssoam2HeadlessOutcome outcome) {
      if (completer.isCompleted) return;
      completer.complete(outcome);
    }

    try {
      webView = HeadlessInAppWebView(
        // **根路徑，不是登入頁。** 直接開 /account/login 一定看得到表單，
        // 就算平台 store 的 cookie 還有效也一樣，於是每次都會撞上 Turnstile。
        // 開根路徑才會讓站台自己決定要不要導走。
        initialUrlRequest: URLRequest(url: WebUri(Ssoam2Login.rootUrl)),
        // **給它一個真實的尺寸。** 預設是 `Size(-1, -1)`，也就是讓平台自己
        // 決定，實務上是接近零的視窗。Turnstile 是要渲染的 widget——viewport
        // 是 0 的話它的 script 可能根本不會跑完，於是 cf-turnstile-response
        // 永遠是空的，而我們會把那個結果誤讀成「需要真人」。
        initialSize: const Size(412, 892),
        // 送出之後的那一段（轉址鏈 + 落地頁載入）是目前最大的成本，而
        // onLoadStop 只在整頁載完才觸發，看不出是哪一半慢。onLoadStart 會在
        // 每一次導航「開始」時觸發，兩者的時間差就是該頁的載入時間。
        onLoadStart: (controller, url) {
          Log.d("[sso-headless] onLoadStart ${url?.host}${url?.path}");
        },
        // console 是唯一看得到 CSP 阻擋與 script 載入錯誤的地方。
        onConsoleMessage: (controller, message) {
          Log.d("[sso-headless] console<${message.messageLevel}> "
              "${message.message}");
        },
        // 資源層級的失敗（例如 challenges.cloudflare.com 連不上）只會出現在
        // 這裡，不會讓 onReceivedError 觸發——後者只管主框架。
        onReceivedHttpError: (controller, request, response) {
          Log.d("[sso-headless] http ${response.statusCode} ${request.url}");
        },
        onReceivedError: (controller, request, error) {
          Log.d("[sso-headless] 載入失敗 ${error.description}");
          finish(Ssoam2HeadlessOutcome.failed);
        },
        onWebViewCreated: (c) => lastController = c,
        onLoadStop: (controller, url) async {
          lastController = controller;
          if (completer.isCompleted) return;
          Log.d("[sso-headless] onLoadStop ${url?.host}${url?.path}");
          final html = await controller.getHtml() ?? "";

          // 已登入。這是最常見也最重要的一條：平台 WebView store 的 cookie
          // 有效、課表載得出來，而 Dio 探針同時回報 signedIn=false——兩套
          // store 不同步。這時不需要重新登入，把 cookie 鏡射過去就好。
          if (Ssoam2Login.isSignedInPage(html)) {
            final moved = await CookieBridge.mirrorToDio(
              url: WebUri(Ssoam2Login.rootUrl),
              jar: jar,
            );
            Log.d("[sso-headless] 平台 store 已登入，鏡射 $moved 顆");
            finish(moved > 0
                ? Ssoam2HeadlessOutcome.success
                : Ssoam2HeadlessOutcome.failed);
            return;
          }

          if (Ssoam2Login.isLoginPage(url)) {
            if (await Ssoam2Login.hasValidationError(controller)) {
              Log.d("[sso-headless] 站台回報登入錯誤");
              finish(Ssoam2HeadlessOutcome.rejected);
              return;
            }
            final outcome = await Ssoam2Login.submit(
              controller,
              account: account,
              password: password,
              // 比可見頁面的 5 秒寬鬆：headless 沒有畫面可以先渲染，
              // Turnstile 的挑戰有可能比較慢。仍在 _budget 之內。
              turnstileTimeout: const Duration(seconds: 8),
            );
            Log.d("[sso-headless] submit=$outcome");
            if (outcome == Ssoam2LoginOutcome.submitted) submitted = true;
            if (outcome == Ssoam2LoginOutcome.turnstileTimeout) {
              // 逾時的原因至少有四種，這裡把它們分開，否則 needsHuman 是猜的。
              Log.d("[sso-headless] turnstile 診斷 "
                  "${await Ssoam2Login.diagnoseTurnstile(controller)}");
            }
            if (outcome != Ssoam2LoginOutcome.submitted) {
              finish(Ssoam2HeadlessOutcome.needsHuman);
            }
            // submitted 的話不收網：等下一次 onLoadStop 看導到哪裡。
            return;
          }

          // 到這裡代表：不是已登入頁，也不是 /account/login。
          //
          // 那就是根路徑在未登入時吐出的表單——它的 markup 與 /account/login
          // 不同（`name="UserName"` 對 `id="Username"`），共用腳本認不得。
          // 既然已經知道沒登入，直接導到 /account/login：那一頁一定顯示表單，
          // 而且是共用腳本認得的那一份。導過去之後 onLoadStop 會再觸發一次，
          // 走上面的 isLoginPage 分支。
          if (!navigatedToForm) {
            navigatedToForm = true;
            Log.d("[sso-headless] 根路徑未登入，導到登入表單");
            await controller.loadUrl(
                urlRequest: URLRequest(url: WebUri(Ssoam2Login.loginPageUrl)));
            return;
          }
          Log.d("[sso-headless] 導過去之後仍然認不得這一頁，交給可見頁面");
          finish(Ssoam2HeadlessOutcome.needsHuman);
        },
      );
      await webView.run();
      // 兩段預算：送出之前緊、送出之後寬。timeout 只能設一次，所以先等
      // 前半；到期時如果已經送出，就再等後半。
      // completer 的型別是不可為 null 的，所以逾時要靠攔 TimeoutException
      // 來表達「還沒有結果」。
      Future<Ssoam2HeadlessOutcome?> waitFor(Duration d) async {
        try {
          return await completer.future.timeout(d);
        } on TimeoutException {
          return null;
        }
      }

      var outcome = await waitFor(_budgetBeforeSubmit);
      if (outcome == null && submitted) {
        Log.d("[sso-headless] 已送出，延長等待");
        outcome = await waitFor(_budgetAfterSubmit);
      }
      if (outcome != null) return outcome;

      // 真的等不到了。**但如果表單已經送出去，先確認一次現在的狀態**——
      // 那一次登入可能其實成功了，只是轉址鏈比我們的耐心長。直接回 failed
      // 會讓使用者看到一個顯示「已經登入」的登入頁。
      if (submitted) {
        final html = await lastController?.getHtml() ?? "";
        if (Ssoam2Login.isSignedInPage(html)) {
          final moved = await CookieBridge.mirrorToDio(
            url: WebUri(Ssoam2Login.rootUrl),
            jar: jar,
          );
          Log.d("[sso-headless] 逾時但已登入，鏡射 $moved 顆");
          if (moved > 0) return Ssoam2HeadlessOutcome.success;
        }
      }
      Log.d("[sso-headless] 逾時");
      return Ssoam2HeadlessOutcome.failed;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return Ssoam2HeadlessOutcome.failed;
    } finally {
      await webView?.dispose();
    }
  }
}

/// [Ssoam2HeadlessLogin.attempt] 的結果。
///
/// 除了 [success]，其餘一律交給可見登入頁——差別只在要不要順帶把站台的
/// 錯誤訊息帶出去。
enum Ssoam2HeadlessOutcome {
  /// 表單送出後被導離登入頁。
  success,

  /// 站台明確回報登入錯誤（多半是密碼錯）。
  rejected,

  /// Turnstile 沒有自動通過，或頁面上找不到表單。
  needsHuman,

  /// 載入失敗或逾時。
  failed,
}
