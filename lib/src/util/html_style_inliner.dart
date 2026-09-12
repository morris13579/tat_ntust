import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart' as css_ast;
import 'package:flutter_app/debug/log/log.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 把 `<style>` 區塊裡的 CSS 展開成各元素的行內 `style` 屬性。
///
/// **為什麼需要這一層**：`flutter_widget_from_html` 只吃行內的 `style` 屬性，
/// 完全不套用 `<style>` 區塊裡的規則。而 Outlook 與 Word 寄出來的信幾乎把所有
/// 排版都寫在 `<style>` 裡，直接算繪等於整封信沒有樣式。
///
/// 這不是完整的 CSS 引擎，也不打算是。它做的是：把規則照文件順序疊到符合的
/// 元素上，元素原本就有的行內樣式優先。沒有做的事情寫在 [inline] 的註解裡。
class HtmlStyleInliner {
  HtmlStyleInliner._();

  /// 最多處理幾條規則。Outlook 的 `<style>` 動輒上百條，而這裡是
  /// O(規則 × 元素) 的比對，不設上限會讓開信卡住。
  static const int _maxRules = 400;

  /// 文件裡最多幾個元素才做這件事。超過就整個跳過——那種信多半是整頁報表，
  /// 展開的成本遠大於好看一點的收益。
  static const int _maxElements = 3000;

  /// 展開之後回傳新的 HTML。任何一步失敗都回原字串——樣式沒展開只是難看，
  /// 把信弄不見就是壞掉。
  ///
  /// 除了展開 `<style>`，還會把 `display: inline-block` 從行內樣式裡拿掉，
  /// 見 [_dropInlineBlock]。
  ///
  /// **沒有做的事**（都是刻意的）：
  /// - `@media`：條件式規則無條件套用會是錯的，直接略過。
  /// - 特異性（specificity）：只照文件順序後蓋前。信件 CSS 幾乎不靠特異性
  ///   打架，為此實作一套權重不划算。
  /// - `!important`：同上，不特別處理。
  /// - 繼承與 cascade 的其餘規則：交給 fwfh 自己算。
  static String inline(String html) {
    final hasStyleBlock = html.contains('<style');
    // `inline-block` 也要處理，而它多半只寫在行內樣式裡——沒有 `<style>` 的
    // 信一樣會中招，所以不能只看 `<style>` 就決定跳過。
    final hasInlineBlock = html.contains('inline-block');
    if (!hasStyleBlock && !hasInlineBlock) return html;
    try {
      final document = html_parser.parse(html);
      final styleElements = document.querySelectorAll('style');

      if (document.querySelectorAll('*').length > _maxElements) {
        Log.d('html inliner: skipped, document too large');
        return html;
      }

      // 元素 → 累積的宣告。用 LinkedHashMap 的插入順序當「後蓋前」。
      final pending = <dom.Element, Map<String, String>>{};
      var applied = 0;

      for (final styleElement in styleElements) {
        // `errors` 給了才不會讓 csslib 把剖析訊息印到 console；信件 CSS 本來就
        // 到處是它不認得的東西，那些訊息對使用者沒有意義。
        final sheet = css.parse(_stripCdo(styleElement.text), errors: []);
        for (final node in sheet.topLevels) {
          if (node is! css_ast.RuleSet) continue; // @media / @font-face 略過
          if (applied >= _maxRules) break;
          applied++;

          final String? selector;
          try {
            selector = node.selectorGroup?.span?.text.trim();
          } catch (_) {
            continue;
          }
          if (selector == null || selector.isEmpty) continue;
          final declarations = _declarationsOf(node.declarationGroup);
          if (declarations.isEmpty) continue;

          final List<dom.Element> matched;
          try {
            matched = document.querySelectorAll(selector);
          } catch (_) {
            // `html` 的選擇器支援度有限（例如 `:hover`、屬性選擇器的某些寫法）。
            // 認不得的規則跳過就好，不要讓整封信失去樣式。
            continue;
          }
          for (final element in matched) {
            (pending[element] ??= <String, String>{}).addAll(declarations);
          }
        }
        // `<style>` 本身不算繪，留著只是多一個節點。
        styleElement.remove();
      }

      _dropInlineBlock(document);

      pending.forEach((element, declarations) {
        final existing = element.attributes['style'] ?? '';
        // 原本就有的行內樣式排在後面 → 蓋過展開進來的，符合 CSS 的特異性直覺。
        final merged = StringBuffer();
        declarations.forEach((property, value) {
          merged.write('$property: $value; ');
        });
        merged.write(existing);
        element.attributes['style'] = merged.toString().trim();
      });

      return document.outerHtml;
    } catch (e, stack) {
      Log.eWithStack('html inliner failed: $e', stack);
      return html;
    }
  }

  /// 把行內樣式裡的 `display: inline-block` 拿掉。
  ///
  /// **為什麼一定要在這一層做。** `flutter_widget_from_html` 沒有實作
  /// `inline-block`，而它判斷 `display` 的那條路（`parseStyleDisplay`）直接
  /// 讀元素的樣式表，不經過 `WidgetFactory.parseStyle`——在 factory 那一層攔
  /// 是攔不到的。只有在 fwfh 看到 HTML 之前改掉 DOM 才有效。
  ///
  /// 兩件事會因此修好：
  /// - **MJML 的欄位不再疊在一起。** Google 日曆邀請、電子報都用
  ///   「`inline-block` + `width: 100%`」排欄位，fwfh 把那些 div 當成行內內容，
  ///   實測那封邀請信裡二十幾段文字全部落在 `x=65, y=173`，畫面上只剩一個有
  ///   框線的空方塊。退回 block 就是它們在窄螢幕上本來就該有的樣子。
  /// - **表格做的按鈕畫得出來。** 「Join with Google Meet」是
  ///   `<a><table style="display:inline-block"><td bgcolor…>`；那個行內宣告
  ///   蓋掉 fwfh 給 `<table>` 的預設 `display: table`，表格演算法整個不註冊，
  ///   `<td>` 的底色、內距與圓角都不算繪，只剩一行白字。
  ///
  /// 只動 `inline-block` 一個值：`display: none` 是要生效的。
  static void _dropInlineBlock(dom.Document document) {
    for (final element in document.querySelectorAll('[style]')) {
      final style = element.attributes['style'];
      if (style == null || !style.toLowerCase().contains('inline-block')) {
        continue;
      }
      final kept = style
          .split(';')
          .where((part) => !_isInlineBlock(part))
          .join(';')
          .trim();
      if (kept.isEmpty) {
        element.attributes.remove('style');
      } else {
        element.attributes['style'] = kept;
      }
    }
  }

  static bool _isInlineBlock(String declaration) {
    final colon = declaration.indexOf(':');
    if (colon < 0) return false;
    return declaration.substring(0, colon).trim().toLowerCase() == 'display' &&
        declaration.substring(colon + 1).trim().toLowerCase() == 'inline-block';
  }

  /// 老信件常把 CSS 包在 HTML 註解裡（`<style><!-- ... --></style>`），那是
  /// 為了讓 1990 年代不認得 `<style>` 的瀏覽器不要把 CSS 當內文印出來。
  /// csslib 不吃這兩個符號，先拆掉。
  static String _stripCdo(String css) =>
      css.replaceAll('<!--', '').replaceAll('-->', '');

  /// 從宣告群組取出 `property -> value`，值用原始碼片段而不是重新輸出——
  /// csslib 的 printer 會把某些寫法正規化掉，原文對 fwfh 更安全。
  static Map<String, String> _declarationsOf(css_ast.DeclarationGroup group) {
    final result = <String, String>{};
    for (final node in group.declarations) {
      if (node is! css_ast.Declaration) continue;
      final String property;
      final String text;
      try {
        // `Declaration.property` 內部是 `_property!`，遇到 `@page` 底下的
        // margin box 之類的節點會直接丟。這裡不值得為它分型別。
        property = node.property.trim().toLowerCase();
        text = node.span.text;
      } catch (_) {
        continue;
      }
      if (property.isEmpty) continue;
      // Word 產的 `mso-*` 一條都不會算繪，留著只是把每個標籤撐長。原本就寫在
      // 行內的那些不動它，這裡只是不要再多加。
      if (property.startsWith('mso-')) continue;
      final colon = text.indexOf(':');
      if (colon < 0) continue;
      final value = text.substring(colon + 1).trim();
      if (value.isEmpty) continue;
      result[property] = value;
    }
    return result;
  }
}
