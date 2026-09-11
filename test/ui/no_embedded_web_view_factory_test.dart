import 'package:flutter_app/ui/components/html/no_embedded_web_view_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NoEmbeddedWebViewFactory 關掉 iframe 自動變成內嵌 WebView', () {
    // 預設 WidgetFactory 的 webView 是 true：HTML 裡一個 <iframe> 就是一個
    // 開著 JavaScript 的 WebView，不需要使用者點任何東西。
    expect(NoEmbeddedWebViewFactory().webView, isFalse);
  });
}
