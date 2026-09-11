import 'dart:convert';

import 'package:flutter_app/debug/log/log.dart';

import 'package:flutter_app/src/util/web_view_utils.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 在 ssoam2 的登入頁上填表、等 Turnstile、按下登入的**唯一**一份實作。
///
/// 這個類別只負責「對一個已經停在登入頁的 WebView 做什麼」。它不決定那個
/// WebView 是可見的還是 headless，也不碰 cookie——那是呼叫端的事。
class Ssoam2Login {
  const Ssoam2Login._();

  static const String host = "https://ssoam2.ntust.edu.tw";

  /// 站台根路徑。沒有登入時它會直接吐出登入表單（**而且 markup 與
  /// [loginPageUrl] 那一頁不同**：根路徑用 `name="UserName"`，登入頁用
  /// `id="Username"`）；已經登入時它顯示的是帳號資訊頁。
  static const String rootUrl = "$host/";

  /// 登入表單的網址。**注意它不等於 [rootUrl]。**
  ///
  /// 直接開這一頁一定看得到表單，就算 cookie 還有效也一樣；開根路徑才會讓
  /// 站台自己決定要不要導走。想知道「現在登入了沒有」必須走根路徑。
  static const String loginPageUrl = "$host/account/login";

  /// 使用者名稱欄位存在，代表登入表單已經渲染完成。
  static const String _formReady =
      'document.getElementById("Username") != null';

  /// Turnstile 已經完成：欄位存在**而且**有值。
  ///
  /// 這兩件事必須分開看。欄位不存在代表這一頁根本沒有 Turnstile；欄位存在
  /// 但空白代表挑戰還沒過。壓成同一個分支的話，沒有 Turnstile 的頁面會被
  /// 誤判成「等逾時」。
  static const String _turnstileDone =
      'document.querySelector(\'[name="cf-turnstile-response"]\') != null && '
      'document.querySelector(\'[name="cf-turnstile-response"]\').value !== ""';

  /// Turnstile 的機制**有沒有真的在運作**。
  ///
  /// 判準不能是「`cf-turnstile-response` 這個欄位存不存在」：ssoam2 的登入頁
  /// 會渲染出容器與隱藏欄位，卻**不給載入 script**（`scriptLoaded: false`、
  /// `iframes: 0`，而 `readyState` 已經是 complete）——也就是那一次根本沒有
  /// 挑戰要過。照那個判準會在那裡等一個永遠不會出現的值，逾時之後被誤讀成
  /// 「需要真人」。
  ///
  /// 真正代表「有挑戰」的是三者之一：API script 跑起來了、widget 的 iframe
  /// 生出來了、或欄位已經有值。
  static const String _turnstileActive =
      'typeof window.turnstile !== "undefined" || '
      'document.querySelector(\'iframe[src*="challenges.cloudflare.com"]\') '
      '!= null || '
      '(document.querySelector(\'[name="cf-turnstile-response"]\') != null && '
      'document.querySelector(\'[name="cf-turnstile-response"]\').value !== "")';

  /// 挑戰**確定不會出現**。
  ///
  /// 三個條件同時成立才算數：頁面已經完全載入、`window.turnstile` 不存在、
  /// DOM 裡沒有 challenges.cloudflare.com 的 script 或 iframe。
  ///
  /// ssoam2 的登入頁會渲染 Turnstile 的容器與隱藏欄位，卻**不給載入
  /// script**。沒有這個早退判定的話，那三秒全部花在等一個不會來的東西——
  /// 佔首次登入總時間的六成。
  ///
  /// **保守的部分**：`readyState` 是 complete 不代表沒有 script 會再插進來
  /// （`load` 事件或 setTimeout 裡都可以），所以早退之前先留 [_turnstileGrace]
  /// 的緩衝，不是一 onLoadStop 就下結論。
  static const String _turnstileNeverComing =
      'document.readyState === "complete" && '
      'typeof window.turnstile === "undefined" && '
      'document.querySelector(\'script[src*="challenges.cloudflare.com"]\') '
      '== null && '
      'document.querySelector(\'iframe[src*="challenges.cloudflare.com"]\') '
      '== null';

  /// 等待可以結束了：不是挑戰在跑，就是確定不會有挑戰。
  static const String _turnstileSettled =
      '($_turnstileActive) || ($_turnstileNeverComing)';

  /// 下「確定不會有挑戰」這個結論之前至少要等的時間。
  ///
  /// 擋的是「script 在 load 之後才被插進來」那一種。300 毫秒對使用者無感，
  /// 但足夠讓同步或近乎同步的插入完成。
  static const Duration _turnstileGrace = Duration(milliseconds: 300);

  static const String _clickLogin =
      'document.getElementById("loginButton").click();';

  /// Turnstile 沒有完成時，把「為什麼」問清楚。
  ///
  /// 逾時本身只代表「`cf-turnstile-response` 在時限內沒有變成非空」，它把
  /// 至少四種原因壓成同一個結論：真的要人點、只是比較慢、script 根本沒載入
  /// 或沒渲染、Cloudflare 偵測到自動化直接拒絕。沒有這段診斷，`needsHuman`
  /// 是猜的。
  ///
  /// 回傳一段 JSON 字串，只有結構性資訊，不含任何頁面內容或憑證。
  static Future<String> diagnoseTurnstile(
      InAppWebViewController controller) async {
    final result = await controller.evaluateJavascript(source: r'''
      (function () {
        var field = document.querySelector('[name="cf-turnstile-response"]');
        var frames = document.querySelectorAll(
            'iframe[src*="challenges.cloudflare.com"]');
        var widget = document.querySelector('.cf-turnstile, [data-sitekey]');
        var cfScript = document.querySelector(
            'script[src*="challenges.cloudflare.com"]');
        var csp = document.querySelector(
            'meta[http-equiv="Content-Security-Policy"]');
        return JSON.stringify({
          scriptLoaded: typeof window.turnstile !== "undefined",
          fieldExists: field != null,
          fieldLen: field ? field.value.length : -1,
          iframes: frames.length,
          widget: widget
              ? (widget.offsetWidth + "x" + widget.offsetHeight)
              : "none",
          viewport: window.innerWidth + "x" + window.innerHeight,
          bodyLen: document.body ? document.body.innerHTML.length : 0,
          // 下面這幾項是為了分辨「標籤不在」與「請求失敗」。
          readyState: document.readyState,
          scripts: document.scripts.length,
          cfScriptTag: cfScript ? cfScript.getAttribute("src") : "none",
          cspMeta: csp ? "yes" : "no"
        });
      })()
    ''');
    return result?.toString() ?? "null";
  }

  /// 登入錯誤訊息的兩層判準，回傳的 JSON 會說是哪一層命中。
  ///
  /// 1. `validation-summary-errors`——實測 `/account/login` 上這個 class 與
  ///    `validation-summary-valid` 都不存在，很可能已經失效，留著零成本。
  /// 2. 掃可見文字找已知句子。**現在實際負責攔截的是這一層。**
  ///
  /// 第二層不能省：呼叫端都把「沒有錯誤」當成「可以再送一次」，判準失效等於
  /// 無限重送同一組錯密碼，而站台是「密碼錯誤 10 次鎖 15 分鐘」。乾淨的登入頁
  /// 不含這兩句話，所以不會把成功的登入判成失敗。
  static const String _credentialErrorJs = r'''
    (function () {
      var box = document.getElementsByClassName(
          "validation-summary-errors")[0];
      if (box) {
        var t = (box.innerText || box.textContent || "").trim();
        if (t) return JSON.stringify({source: "class", message: t});
      }
      // innerText 依賴排版，headless WebView 可能回空字串，留 textContent 後路。
      var body = document.body
          ? (document.body.innerText || document.body.textContent || "")
          : "";
      var low = body.toLowerCase();
      var marks = ["帳號或密碼輸入錯誤", "username or password is incorrect"];
      for (var i = 0; i < marks.length; i++) {
        var k = low.indexOf(marks[i].toLowerCase());
        if (k >= 0) {
          var line = body.substring(k, k + 160).split("\n")[0].trim();
          return JSON.stringify({source: "text", message: line});
        }
      }
      return JSON.stringify({source: "none", message: ""});
    })()
  ''';

  /// 站台回報的登入錯誤訊息，沒有就是 null。
  ///
  /// **呼叫端一定要在再送出表單之前先問這個。** 登入失敗後站台是把登入頁
  /// 連同錯誤訊息重新吐回來，網址仍是登入頁，先送出再檢查等於永遠檢查不到。
  static Future<String?> credentialError(
      InAppWebViewController controller) async {
    try {
      final raw =
          await controller.evaluateJavascript(source: _credentialErrorJs);
      if (raw == null) return null;
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map) return null;
      final message = (decoded["message"] as String? ?? "").trim();
      if (message.isEmpty) return null;
      if (decoded["source"] == "text") {
        Log.e("[ssoam2] validation-summary-errors 不見了，"
            "靠文字比對才認出登入錯誤——站台改版了，該更新判準");
      }
      return message;
    } catch (e, stack) {
      // 讀不到就當作沒有錯誤，下一輪還會再問。
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  /// 站台是不是在頁面上回報了登入錯誤。判準與 [credentialError] 同一份。
  static Future<bool> hasValidationError(
          InAppWebViewController controller) async =>
      await credentialError(controller) != null;

  /// 這份 HTML 是不是「已經登入」的帳號資訊頁。
  ///
  /// 判準是站台在該頁上印的三個英文字串，全 lib 唯一一份定義；不要再抄第二
  /// 份。站台若切換語系會誤判成沒登入（後果是多跑一次登入，良性）。
  static bool isSignedInPage(String html) =>
      html.contains("Issued") &&
      html.contains("Expires") &&
      html.contains("You are signed in as");

  /// 這一頁是不是 ssoam2 的登入表單。
  static bool isLoginPage(Object? url) =>
      url != null && url.toString().startsWith(loginPageUrl);

  /// 填表、等 Turnstile、送出。
  ///
  /// [turnstileTimeout] 預設沿用 `waitForElement` 的 5 秒。
  static Future<Ssoam2LoginOutcome> submit(
    InAppWebViewController controller, {
    required String account,
    required String password,
    Duration turnstileTimeout = const Duration(seconds: 5),
    Duration turnstileAppearTimeout = const Duration(seconds: 3),
  }) async {
    if (!await controller.waitForElement(condition: _formReady)) {
      return Ssoam2LoginOutcome.formNotFound;
    }

    await controller.evaluateJavascript(
        source: 'document.getElementById("Username").value = '
            '${jsonEncode(account)};');
    await controller.evaluateJavascript(
        source: 'document.getElementById("Password").value = '
            '${jsonEncode(password)};');

    // 先給挑戰一點時間「出現」。script 是非同步載入的，剛 onLoadStop 時
    // 通常還看不到；但如果這一頁根本沒有挑戰，等再久也不會出現——所以等的
    // 條件是「有挑戰」**或**「確定不會有挑戰」，兩者都算塵埃落定。
    await Future<void>.delayed(_turnstileGrace);
    await controller.waitForElement(
        condition: _turnstileSettled, timeout: turnstileAppearTimeout);
    final active =
        await controller.evaluateJavascript(source: _turnstileActive) == true;
    // 記下走了哪一條。學校哪天開始下發挑戰時，這一行會從「無挑戰」變成
    // 「有挑戰」——那是行為改變的第一個訊號。
    Log.d("[ssoam2] turnstile ${active ? "有挑戰，等它完成" : "無挑戰，直接送出"}");
    if (!active) {
      // 沒有挑戰在跑就直接送出。伺服器若真的要 Turnstile 會拒絕，
      // 那時頁面上會有 validation-summary-errors，呼叫端看得到。
      await controller.evaluateJavascript(source: _clickLogin);
      return Ssoam2LoginOutcome.submitted;
    }

    // 有挑戰，等它完成。
    if (!await controller.waitForElement(
        condition: _turnstileDone, timeout: turnstileTimeout)) {
      return Ssoam2LoginOutcome.turnstileTimeout;
    }

    await controller.evaluateJavascript(source: _clickLogin);
    return Ssoam2LoginOutcome.submitted;
  }
}

/// [Ssoam2Login.submit] 的結果。
enum Ssoam2LoginOutcome {
  /// 已按下登入。這**不**代表登入成功——密碼錯誤也會走到這裡，
  /// 結果要看接下來導到哪一頁。
  submitted,

  /// Turnstile 沒有在時限內完成，需要真人操作。
  turnstileTimeout,

  /// 頁面上找不到登入表單。
  formNotFound,
}
