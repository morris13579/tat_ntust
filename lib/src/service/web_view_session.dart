import 'dart:async';
import 'dart:ui';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 能被驅動的 WebView。Flutter App 是 flutter_inappwebview，原生版是 Swift 的 WKWebView。
///
/// 登入腳本（`Ssoam2Login`）只認得這個介面，兩個平台跑的才是同一份判準。
abstract class WebViewDriver {
  Future<Object?> evaluateJavascript(String source);

  Future<String?> getHtml();

  Future<void> loadUrl(String url);
}

extension WebViewDriverWait on WebViewDriver {
  Future<bool> waitForElement({
    required String condition,
    Duration timeout = const Duration(seconds: 5),
    Duration pollingInterval = const Duration(milliseconds: 200),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      if (await evaluateJavascript(condition) == true) return true;
      await Future<void>.delayed(pollingInterval);
    }
    return false;
  }
}

sealed class WebViewEvent {
  const WebViewEvent();
}

/// 一頁載完。轉址鏈的每一站都會來一次。
final class WebViewLoadStop extends WebViewEvent {
  const WebViewLoadStop(this.url);

  final String? url;
}

/// 主框架載入失敗。
final class WebViewLoadError extends WebViewEvent {
  const WebViewLoadError(this.description);

  final String description;
}

/// 導到要攔下的 scheme（例如 `moodlemobile://`），導航已經被擋掉。
final class WebViewIntercepted extends WebViewEvent {
  const WebViewIntercepted(this.url);

  final String url;
}

/// 使用者自己關掉了可見的頁面。
final class WebViewDismissed extends WebViewEvent {
  const WebViewDismissed();
}

/// 一個開著的 WebView。事件在有人 listen 之前會先排隊，開完再 listen 不會漏掉第一頁。
abstract class WebViewSession implements WebViewDriver {
  Stream<WebViewEvent> get events;

  Future<void> close();
}

/// 開 headless WebView 的唯一入口。原生版由 `core_main.dart` 換掉 [instance]。
abstract class HeadlessWebViewHost {
  static HeadlessWebViewHost instance = const InAppHeadlessWebViewHost();

  Future<WebViewSession> open(String url);
}

/// flutter_inappwebview 的 controller 包成 [WebViewDriver]，給 Flutter 的可見頁面用。
class InAppWebViewDriver implements WebViewDriver {
  const InAppWebViewDriver(this.controller);

  final InAppWebViewController controller;

  @override
  Future<Object?> evaluateJavascript(String source) =>
      controller.evaluateJavascript(source: source);

  @override
  Future<String?> getHtml() => controller.getHtml();

  @override
  Future<void> loadUrl(String url) =>
      controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
}

/// Flutter App 的實作：`HeadlessInAppWebView`。
class InAppHeadlessWebViewHost implements HeadlessWebViewHost {
  const InAppHeadlessWebViewHost();

  @override
  Future<WebViewSession> open(String url) async {
    final session = _InAppHeadlessSession();
    await session._start(url);
    return session;
  }
}

class _InAppHeadlessSession implements WebViewSession {
  final _events = StreamController<WebViewEvent>();
  HeadlessInAppWebView? _webView;
  InAppWebViewController? _controller;

  Future<void> _start(String url) async {
    final webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      // **給它一個真實的尺寸。** 預設的 `Size(-1, -1)` 實務上是接近零的視窗，而 Turnstile 是要
      // 渲染的 widget——viewport 是 0 的話它的 script 可能根本不會跑完。
      initialSize: const Size(412, 892),
      // 下面三個只記 log：onLoadStop 看不出是哪一段慢；console 是唯一看得到 CSP 阻擋與
      // script 載入錯誤的地方；資源層級的失敗不會讓 onReceivedError 觸發。
      onLoadStart: (controller, url) =>
          Log.d("[web-session] onLoadStart ${url?.host}${url?.path}"),
      onConsoleMessage: (controller, message) => Log.d(
          "[web-session] console<${message.messageLevel}> ${message.message}"),
      onReceivedHttpError: (controller, request, response) =>
          Log.d("[web-session] http ${response.statusCode} ${request.url}"),
      onReceivedError: (controller, request, error) =>
          _add(WebViewLoadError(error.description)),
      onWebViewCreated: (controller) => _controller = controller,
      onLoadStop: (controller, url) {
        _controller = controller;
        _add(WebViewLoadStop(url?.toString()));
      },
    );
    _webView = webView;
    await webView.run();
  }

  void _add(WebViewEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Stream<WebViewEvent> get events => _events.stream;

  @override
  Future<Object?> evaluateJavascript(String source) async =>
      _controller?.evaluateJavascript(source: source);

  @override
  Future<String?> getHtml() async => _controller?.getHtml();

  @override
  Future<void> loadUrl(String url) async =>
      _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));

  @override
  Future<void> close() async {
    // 不 await：沒有人 listen 過的 controller，close 的 Future 永遠不會完成。
    unawaited(_events.close());
    // 原生端以 HashMap 強持有，不 dispose 不會被回收。
    await _webView?.dispose();
  }
}
