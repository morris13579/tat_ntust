import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 深色模式下中和 HTML 自帶顏色的規則。Flutter 的 `NoEmbeddedWebViewFactory`
/// 算繪時照這裡丟宣告；原生版的信件 WebView 照 [markNeutral] 標出來的元素用
/// CSS 蓋掉，兩邊中和的是同一批元素。
class HtmlColors {
  HtmlColors._();

  static const String neutralAttribute = 'data-tat-neutral';

  /// `background` 這個縮寫也要丟。只擋 `background-color` 的話，Word 簽名檔
  /// 那種 `background:white` 會留下來，而它的 `color` 已經被丟掉換成主題的
  /// 淺色前景——白底配白字，整段看不見。
  static const Set<String> _neutralized = {
    'color',
    'background-color',
    'background',
  };

  static bool neutralizes(String property) => _neutralized.contains(property);

  /// 這個元素或它的祖先自己指定過底色嗎。
  ///
  /// **有指定底色的那一塊不要中和。** 中和是為了處理「從 Word 貼上的
  /// `color:#000`」——作者只設了字色、把底色交給郵件軟體，深色模式下就變成
  /// 深底黑字。但作者同時設了底色與字色的時候，那兩個顏色是配好的一組：
  /// Google 日曆邀請的「Join with Google Meet」是 `<td>` 藍底配 `<span>` 白字，
  /// 把底色丟掉就只剩一行白字，按鈕整個不見了。
  ///
  /// 要往上找祖先：底色在 `<td>` 上，字色在它裡面的 `<span>` 上。
  static bool hasAuthoredBackground(dom.Element? element) {
    for (var node = element; node != null; node = node.parent) {
      final style = node.attributes['style']?.toLowerCase();
      if (style == null) continue;
      for (final part in style.split(';')) {
        final colon = part.indexOf(':');
        if (colon < 0) continue;
        final property = part.substring(0, colon).trim();
        if (property != 'background' && property != 'background-color') {
          continue;
        }
        final value = part.substring(colon + 1).trim();
        // `background: none` 之類的不算指定。
        if (value.isEmpty ||
            value == 'none' ||
            value == 'transparent' ||
            value == 'inherit' ||
            value == 'initial') {
          continue;
        }
        return true;
      }
    }
    return false;
  }

  /// 行內樣式帶著要中和的顏色、又沒有配好的底色的元素，加上 [neutralAttribute]。
  /// 一個都沒有就原樣回傳，不重新序列化。
  static String markNeutral(String html) {
    if (!html.contains(RegExp('style', caseSensitive: false))) return html;
    final document = html_parser.parse(html);
    var marked = false;
    for (final element in document.querySelectorAll('[style]')) {
      if (!_declaresNeutralized(element.attributes['style'] ?? '')) continue;
      if (hasAuthoredBackground(element)) continue;
      element.attributes[neutralAttribute] = '';
      marked = true;
    }
    return marked ? document.outerHtml : html;
  }

  static bool _declaresNeutralized(String style) {
    for (final part in style.toLowerCase().split(';')) {
      final colon = part.indexOf(':');
      if (colon >= 0 && neutralizes(part.substring(0, colon).trim())) {
        return true;
      }
    }
    return false;
  }
}
