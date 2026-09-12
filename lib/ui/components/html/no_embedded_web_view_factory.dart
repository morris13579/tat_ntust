import 'package:csslib/visitor.dart' as css;
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

/// 關掉預設的「`<iframe>` 自動變成內嵌 WebView」：那等於讓教材 HTML 免點擊就
/// 跑起一個開著 JavaScript 的第三方頁面。關掉後 iframe 退化成可點連結。
class NoEmbeddedWebViewFactory extends WidgetFactory {
  NoEmbeddedWebViewFactory({this.neutralizeColors = false});

  /// 丟掉 HTML 自己指定的前景與底色，一律用主題色。深色模式要開：教材多半是
  /// 從 Word 或編輯器貼上的 `color:#000`，留著就是深底黑字。
  final bool neutralizeColors;

  /// `background` 這個縮寫也要丟。只擋 `background-color` 的話，Word 簽名檔
  /// 那種 `background:white` 會留下來，而它的 `color` 已經被丟掉換成主題的
  /// 淺色前景——白底配白字，整段看不見。
  static const Set<String> _neutralized = {
    'color',
    'background-color',
    'background',
  };

  /// 這個屬性在 [neutralizeColors] 打開時會被丟掉嗎。
  @visibleForTesting
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
  static bool _hasAuthoredBackground(dom.Element? element) {
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

  /// 這一條宣告要不要整個丟掉——與深色模式無關，任何時候都丟。
  ///
  /// 目前只有 **`font-size: 0`**：這是 email 用來消掉 inline-block 之間空白
  /// 的老招，搭配子元素再設回 13px。fwfh 會老實地把繼承到的 0 畫出來，漏設
  /// 回去的那幾段就變成寬高都是 0 的看不見的字。
  ///
  /// **`display` 不能在這裡處理。** 它根本不會走到 [parseStyle]——fwfh 的
  /// `display` 是另一條路（`core_build_tree.dart` 的 `parseStyleDisplay`
  /// 直接讀 `_styles`），這裡收不到。`inline-block` 的處理在
  /// [HtmlStyleInliner]，那一層是在 fwfh 看到 HTML 之前就改掉 DOM。
  @visibleForTesting
  static bool alwaysDropped(String property, String value) {
    final v = value.trim().toLowerCase();
    if (property == 'font-size') return v == '0' || v == '0px' || v == '0pt';
    return false;
  }

  @override
  bool get webView => false;

  @override
  void parseStyle(BuildTree tree, css.Declaration style) {
    final String property;
    try {
      // `Declaration.property` 內部是 `_property!`，`@page` 底下的 margin box
      // 之類的節點會直接丟。
      property = style.property.trim().toLowerCase();
    } catch (_) {
      return;
    }
    if (neutralizeColors &&
        neutralizes(property) &&
        !_hasAuthoredBackground(tree.element)) {
      return;
    }
    if (alwaysDropped(property, _valueOf(style))) return;
    super.parseStyle(tree, style);
  }

  /// 宣告的值。用原始碼片段而不是重新輸出——csslib 的 printer 會把某些寫法
  /// 正規化掉，這裡只是要比對字面值。
  static String _valueOf(css.Declaration style) {
    try {
      final text = style.span.text;
      final colon = text.indexOf(':');
      return colon < 0 ? '' : text.substring(colon + 1);
    } catch (_) {
      return '';
    }
  }
}
