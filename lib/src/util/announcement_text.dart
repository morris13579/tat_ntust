/// TAT 公告（Markdown）的純文字處理。
class AnnouncementText {
  AnnouncementText._();

  /// 公告內文是 Markdown，摘要要的是純文字：卡片上只有三行，`**粗體**` 的
  /// 星號與整串網址佔掉的是那三行裡的字。
  static String plainExcerpt(String markdown) {
    var value = markdown
        .replaceAll(_codeFence, ' ')
        .replaceAll(_image, ' ')
        .replaceAllMapped(_link, (m) => m[1] ?? '')
        .replaceAll(_bullet, '')
        .replaceAll(_marks, '');
    value = value.replaceAll(_whitespace, ' ').trim();
    return value;
  }

  static final RegExp _codeFence = RegExp(r'```[\s\S]*?```');
  static final RegExp _image = RegExp(r'!\[[^\]]*\]\([^)]*\)');
  static final RegExp _link = RegExp(r'\[([^\]]*)\]\([^)]*\)');
  static final RegExp _bullet =
      RegExp(r'^[ \t]*(?:[-+*]|\d+\.)[ \t]+', multiLine: true);
  static final RegExp _marks = RegExp(r'[*_`>#~]');
  static final RegExp _whitespace = RegExp(r'\s+');
}
