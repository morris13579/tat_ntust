import 'dart:convert';

/// 工具列送得出去的指令。**刻意是 enum 而不是字串**：這樣沒有任何一條 UI
/// 路徑組得出自由字串的 JS，`document.execCommand` 的引數永遠來自這份固定集合。
///
/// 這一組照官方 App 的 `rich-text-editor`（bold / italic / underline /
/// strike / p / h3 / h4 / h5 / ul / ol / removeFormat）；沒有插入圖片，
/// 官方 App 也沒有。
enum EditorCommand {
  bold,
  italic,
  underline,
  strikeThrough,
  paragraph,
  heading3,
  heading4,
  heading5,
  unorderedList,
  orderedList,
  removeFormat,
}

/// 編輯器橋接的純函式。**刻意不含任何 Moodle 概念**：作業的線上文字那條路
/// 之後要重用它，而 util → util 的橫向 import 是被 tool/deps.py 擋掉的。
class RichEditorBridgeUtils {
  RichEditorBridgeUtils._();

  /// 貼文 HTML 進到頁面的**唯一**合法途徑：包成一個 JS 字串常值。
  ///
  /// `jsonEncode` 之外還要多逃五種字元。`<` / `>` / `&` 是為了任何會把這段
  /// 呼叫再序列化一次的情境——原文裡的 `</script>` 會就地結束 script 區塊；
  /// U+2028 / U+2029 在舊的 JS 文法裡是**沒有逃脫的換行**，`jsonEncode`
  /// 原樣放行，貼進 script 就是語法錯誤。
  static String jsStringLiteral(String value) => jsonEncode(value)
      .replaceAll('<', r'\u003C')
      .replaceAll('>', r'\u003E')
      .replaceAll('&', r'\u0026')
      .replaceAll('\u2028', r'\u2028')
      .replaceAll('\u2029', r'\u2029');

  static String buildSetContentCall(String html) =>
      'window.__tatEditor.setContent(${jsStringLiteral(html)});';

  static String buildCommandCall(EditorCommand command) =>
      'window.__tatEditor.exec("${tokenOf(command)}");';

  /// 深淺色只有宿主知道：頁面的底色是 Flutter 畫在透明 WebView 後面的，會跟著
  /// 主題重畫，字色卻寫在頁面的 CSS 裡。只推一次的話，系統中途換深色就會變成
  /// 同色不可讀，所以這一句要能重推。
  static String buildThemeCall({required bool dark}) =>
      'document.documentElement.setAttribute('
      '"data-theme", "${dark ? 'dark' : 'light'}");';

  /// 指令與橋接兩端共用的字面值。頁面那一端在 assets/editor/editor.js。
  static String tokenOf(EditorCommand command) => switch (command) {
        EditorCommand.bold => 'bold',
        EditorCommand.italic => 'italic',
        EditorCommand.underline => 'underline',
        EditorCommand.strikeThrough => 'strikeThrough',
        EditorCommand.paragraph => 'p',
        EditorCommand.heading3 => 'h3',
        EditorCommand.heading4 => 'h4',
        EditorCommand.heading5 => 'h5',
        EditorCommand.unorderedList => 'ul',
        EditorCommand.orderedList => 'ol',
        EditorCommand.removeFormat => 'removeFormat',
      };

  static final Set<String> _tokens = {
    for (final c in EditorCommand.values) tokenOf(c),
  };

  /// 橋接回報的 `{"bold":true,…,"block":"h3"}` → 目前生效的格式集合。
  ///
  /// **對任何輸入都不可以拋。** 這是 WebView 送進 Dart 的資料，而頁面裡的
  /// 內容是貼文作者寫的；形狀不對就當成「什麼格式都沒生效」，不要讓一個壞掉
  /// 的 payload 打死整個編輯器。
  static Set<String> parseEditorState(Object? raw) {
    if (raw is! Map) return const {};
    final active = <String>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) continue;
      if (key == 'block') {
        final block = entry.value;
        if (block is String && _tokens.contains(block)) active.add(block);
        continue;
      }
      if (entry.value == true && _tokens.contains(key)) active.add(key);
    }
    return active;
  }
}
