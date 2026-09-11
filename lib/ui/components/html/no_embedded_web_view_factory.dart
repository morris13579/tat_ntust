import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

/// 關掉預設的「`<iframe>` 自動變成內嵌 WebView」：那等於讓教材 HTML 免點擊就
/// 跑起一個開著 JavaScript 的第三方頁面。關掉後 iframe 退化成可點連結。
class NoEmbeddedWebViewFactory extends WidgetFactory {
  NoEmbeddedWebViewFactory({this.neutralizeColors = false});

  /// 丟掉 HTML 自己指定的 color / background-color，一律用主題色。深色模式要
  /// 開：教材多半是從 Word 或編輯器貼上的 `color:#000`，留著就是深底黑字。
  final bool neutralizeColors;

  static const Set<String> _colorProperties = {'color', 'background-color'};

  @override
  bool get webView => false;

  /// 參數型別是 `csslib` 的 `Declaration`，但 csslib 不是這個專案的直接相依，
  /// 宣告成 dynamic 才不用為了一個屬性名多加一條 import。
  @override
  void parseStyle(BuildTree tree, dynamic style) {
    if (neutralizeColors &&
        _colorProperties.contains(style.property as String)) {
      return;
    }
    super.parseStyle(tree, style);
  }
}
