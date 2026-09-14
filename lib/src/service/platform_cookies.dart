import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 平台 WebView store 上的一顆 cookie，只留鏡射需要的欄位。
class PlatformCookie {
  const PlatformCookie({
    required this.name,
    required this.value,
    this.secure,
    this.httpOnly,
  });

  final String name;
  final String value;

  /// 取不到時是 null，呼叫端要當成 true（見 [CookieBridge.mirrorToDio]）。
  final bool? secure;
  final bool? httpOnly;
}

/// 「平台 WebView 上有哪些 cookie」的唯一入口。
///
/// 抽成介面是為了原生版：那邊的 WebView 是 Swift 的 `WKWebView`，
/// 由 `core_main.dart` 換掉 [instance]。Flutter App 維持
/// [InAppWebViewCookieSource]。
abstract class PlatformCookieSource {
  static PlatformCookieSource instance = const InAppWebViewCookieSource();

  /// 讀 [url] 上的 cookie。讀不到時**拋**，不要回空清單——
  /// 「真的沒有」與「問不到」的後果完全不同，判斷留給呼叫端。
  Future<List<PlatformCookie>> cookies(String url);
}

class InAppWebViewCookieSource implements PlatformCookieSource {
  const InAppWebViewCookieSource();

  @override
  Future<List<PlatformCookie>> cookies(String url) async {
    final raw = await CookieManager.instance().getCookies(url: WebUri(url));
    return raw
        .map((c) => PlatformCookie(
              name: c.name,
              value: c.value.toString(),
              secure: c.isSecure,
              httpOnly: c.isHttpOnly,
            ))
        .toList();
  }
}

/// 測試用。
class FakeCookieSource implements PlatformCookieSource {
  FakeCookieSource(this.result, {this.throwOnRead = false});

  final List<PlatformCookie> result;
  bool throwOnRead;

  @override
  Future<List<PlatformCookie>> cookies(String url) async {
    if (throwOnRead) {
      Log.d('FakeCookieSource: 故意失敗');
      throw Exception('cookie store unavailable');
    }
    return result;
  }
}
