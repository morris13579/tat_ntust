import 'package:flutter_app/ui/components/html/no_embedded_web_view_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NoEmbeddedWebViewFactory 關掉 iframe 自動變成內嵌 WebView', () {
    // 預設 WidgetFactory 的 webView 是 true：HTML 裡一個 <iframe> 就是一個
    // 開著 JavaScript 的 WebView，不需要使用者點任何東西。
    expect(NoEmbeddedWebViewFactory().webView, isFalse);
  });

  group('深色模式丟掉信件自己指定的顏色', () {
    test('前景與底色都丟', () {
      expect(NoEmbeddedWebViewFactory.neutralizes('color'), isTrue);
      expect(NoEmbeddedWebViewFactory.neutralizes('background-color'), isTrue);
    });

    test('background 這個縮寫也要丟，否則簽名檔會白底白字', () {
      // Word 的簽名檔寫的是 `background:white`，不是 background-color。漏掉
      // 它的話底色留著、前景被換成主題的淺色，那一段就整個看不見了。
      expect(NoEmbeddedWebViewFactory.neutralizes('background'), isTrue);
    });

    test('排版屬性不受影響', () {
      // 丟的只有顏色。連 margin、font-size 一起丟的話信就沒有版面了。
      expect(NoEmbeddedWebViewFactory.neutralizes('margin'), isFalse);
      expect(NoEmbeddedWebViewFactory.neutralizes('font-size'), isFalse);
    });
  });
}
