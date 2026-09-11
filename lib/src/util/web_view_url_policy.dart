import 'package:flutter_app/debug/log/log.dart';

/// 「這個連結能不能交給 App 內的 WebView 開」的唯一規則。
class WebViewUrlPolicy {
  WebViewUrlPolicy._();

  /// 只放行 http / https，擋掉 `javascript:`、`file:`、`data:` 與自訂 scheme。
  /// WebView 會被灌入 cookie，所以「開什麼網址」是帶身分的操作。
  static bool isSafe(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      // 沒有 scheme 代表 HtmlWidget 沒能解析成絕對網址，只會開出壞掉的頁面。
      return false;
    }
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  /// `HtmlWidget.onTapUrl` 的實作。回傳值語意跟直覺相反：回 false 會 fallback
  /// 去 `launchUrl`，等於交給作業系統開，所以擋掉的情況也一律回 true。
  static bool handleTap(
    String url, {
    required void Function(String url) openInWebView,
  }) {
    // 交出去的必須是 isSafe 驗過的同一個字串，否則就是「用 A 驗證、拿 B 使用」。
    final target = url.trim();
    if (isSafe(target)) {
      openInWebView(target);
    } else {
      Log.d("blocked non-http(s) link in course html: $url");
    }
    return true;
  }
}
