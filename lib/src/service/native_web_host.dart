import 'package:flutter_app/generated/core_api.g.dart' as native;
import 'package:flutter_app/src/service/native_web_session.dart';
import 'package:flutter_app/src/service/platform_cookies.dart';
import 'package:flutter_app/src/service/web_page_loader.dart';

/// 原生版的 WebView 這一側：真正的 `WKWebView` 在 Swift。
///
/// 由 `core_main.dart` 安裝，取代 Flutter App 用的 flutter_inappwebview 實作。
/// 兩個介面一起換：cookie 與頁面載入問的是**同一個** `WKWebsiteDataStore`，
/// 分開換掉會出現「登入頁寫在 A、成績頁讀 B」這種只在實機上才看得到的錯。
class NativeWebHost implements PlatformCookieSource, WebPageLoader {
  NativeWebHost([native.TatCoreUiApi? api])
      : _api = api ?? native.TatCoreUiApi();

  final native.TatCoreUiApi _api;

  static void install([native.TatCoreUiApi? api]) {
    final host = NativeWebHost(api);
    PlatformCookieSource.instance = host;
    WebPageLoader.instance = host;
    NativeWebSessions.install(api);
  }

  @override
  Future<List<PlatformCookie>> cookies(String url) async {
    final raw = await _api.webCookies(url);
    return raw
        .map((c) => PlatformCookie(
              name: c.name,
              value: c.value,
              secure: c.secure,
              httpOnly: c.httpOnly,
            ))
        .toList();
  }

  @override
  Future<WebPageResult> load(WebPageRequest request) async {
    final result = await _api.loadPage(native.PageLoadRequest(
      url: request.url,
      completeWhenHtmlContainsAll: request.completeWhenHtmlContainsAll,
      failWhenUrlContainsAny: request.failWhenUrlContainsAny,
      timeoutSeconds: request.timeout.inSeconds,
    ));
    return WebPageResult(
      switch (result.outcome) {
        native.PageLoadOutcome.ok => WebPageOutcome.ok,
        native.PageLoadOutcome.redirectedToLogin =>
          WebPageOutcome.redirectedToLogin,
        native.PageLoadOutcome.timeout => WebPageOutcome.timeout,
        native.PageLoadOutcome.error => WebPageOutcome.error,
      },
      html: result.html,
      detail: result.detail,
    );
  }
}
