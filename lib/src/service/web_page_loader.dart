import 'dart:async';
import 'dart:ui';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 要載哪一頁、什麼時候算「到站」。
class WebPageRequest {
  const WebPageRequest({
    required this.url,
    required this.completeWhenHtmlContainsAll,
    this.failWhenUrlContainsAny = const [],
    this.timeout = const Duration(seconds: 20),
  });

  final String url;

  /// HTML 要**同時**含有這些字串才算到站。
  ///
  /// **不可以只看網址。** 未登入時的轉址鏈最後一站是 ssoam2 的自動送出表單，
  /// 網址同樣含 `StuScoreQuery`。在中途站收網會解析出一份非 null 的空結果，
  /// 呼叫端當成功寫回硬碟。
  final List<String> completeWhenHtmlContainsAll;

  /// 網址含其中任一個代表被踢回登入頁——等下去不會變好，直接失敗。
  final List<String> failWhenUrlContainsAny;

  /// **不可以拿掉。** 外層進度框是全螢幕、不可點擊的遮罩，不收網使用者只能殺掉 App。
  final Duration timeout;
}

enum WebPageOutcome { ok, redirectedToLogin, timeout, error }

class WebPageResult {
  const WebPageResult(this.outcome, {this.html, this.detail});

  final WebPageOutcome outcome;
  final String? html;
  final String? detail;

  static const WebPageResult timedOut = WebPageResult(WebPageOutcome.timeout);
}

/// 「用平台的 WebView 載一頁、把 HTML 拿回來」的唯一入口。
///
/// 抽成介面是為了原生版：那邊的 WebView 是 Swift 的 `WKWebView`，
/// 由 `core_main.dart` 換掉 [instance]。Flutter App 維持
/// [InAppWebViewPageLoader]，行為與抽出來之前逐行相同。
abstract class WebPageLoader {
  static WebPageLoader instance = const InAppWebViewPageLoader();

  Future<WebPageResult> load(WebPageRequest request);
}

/// Flutter App 的實作：`HeadlessInAppWebView`。
class InAppWebViewPageLoader implements WebPageLoader {
  const InAppWebViewPageLoader();

  @override
  Future<WebPageResult> load(WebPageRequest request) async {
    final completer = Completer<WebPageResult>();
    HeadlessInAppWebView? webView;
    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(request.url)),
        // 給它真實尺寸：預設近乎零的 viewport 會讓推進轉址鏈的
        // document.form.submit() 延後執行。
        initialSize: const Size(412, 892),
        onLoadStop: (controller, url) async {
          // client-side 導向會讓 onLoadStop 觸發第二次，重複 complete 丟出的
          // StateError 在 plugin 的 async 回呼裡外層 try 接不到。
          if (completer.isCompleted) return;
          final current = url?.toString() ?? "";
          if (request.failWhenUrlContainsAny.any(current.contains)) {
            completer.complete(
                WebPageResult(WebPageOutcome.redirectedToLogin, detail: current));
            return;
          }
          final html = await controller.getHtml() ?? "";
          // **只在真的到站時才收網。** onLoadStop 在轉址鏈的每一站都會觸發；
          // 不符就直接 return，讓鏈繼續跑。
          if (request.completeWhenHtmlContainsAll.every(html.contains)) {
            completer.complete(WebPageResult(WebPageOutcome.ok, html: html));
            return;
          }
          Log.d("web page: 略過中途頁 ${url?.host}${url?.path}");
        },
        onReceivedError: (controller, req, error) {
          if (completer.isCompleted) return;
          Log.e("web page load error: ${error.description}");
          completer.complete(
              WebPageResult(WebPageOutcome.error, detail: error.description));
        },
      );
      await webView.run();
      return await completer.future.timeout(
        request.timeout,
        onTimeout: () {
          Log.e("web page timeout: ${request.url}");
          return WebPageResult.timedOut;
        },
      );
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return WebPageResult(WebPageOutcome.error, detail: e.toString());
    } finally {
      // 原生端以 HashMap 強持有，不 dispose 不會被回收。
      await webView?.dispose();
    }
  }
}
