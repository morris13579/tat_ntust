/// 評量方式的一個項目：一個名目與它佔的百分比。
class GradingItem {
  const GradingItem(this.label, this.percent);

  final String label;
  final num percent;

  /// 去掉沒有意義的小數點，30.0% 要印成 30%。
  String get percentText {
    final rounded = percent.round();
    final text = percent == rounded ? '$rounded' : '$percent';
    return '$text%';
  }

  @override
  bool operator ==(Object other) =>
      other is GradingItem && other.label == label && other.percent == percent;

  @override
  int get hashCode => Object.hash(label, percent);

  @override
  String toString() => 'GradingItem($label, $percentText)';
}

/// 把 querycourse 回來的「評量方式」拆成可以表格化的項目。
///
/// 這個欄位沒有格式規範：老師想打「期中考30% 期末考40% 平時30%」還是整段
/// 敘述都可以。拆得出完整的百分比清單才表格化，只要有一段拆不出來就整段
/// 回 null，讓呼叫端退回純文字——把敘述硬切成表格比不切還難讀。
class CourseGradingUtils {
  CourseGradingUtils._();

  /// 標籤超過這個長度多半是句子而不是名目。
  static const int _maxLabelLength = 20;

  static final RegExp _fullWidthDigit = RegExp('[０-９]');
  static final RegExp _item =
      RegExp(r'^(.*?)[\s:：=－-]*(\d{1,3}(?:\.\d+)?)\s*%$');

  /// 拆不出完整的百分比清單時回 null。
  static List<GradingItem>? parse(String raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return null;

    final items = <GradingItem>[];
    // 每個 % 之後切一刀，同一行擠好幾項與一項一行都吃得下。
    for (final segment in normalized.replaceAll('%', '%\n').split('\n')) {
      final text = segment.trim();
      if (text.isEmpty) continue;

      final match = _item.firstMatch(text);
      if (match == null) return null;

      final label = _cleanLabel(match.group(1)!);
      if (label.isEmpty || label.length > _maxLabelLength) return null;
      // 句號代表這是敘述，不是名目。
      if (label.contains('。') || label.contains('..')) return null;

      final percent = num.tryParse(match.group(2)!);
      if (percent == null) return null;
      items.add(GradingItem(label, percent));
    }

    return items.isEmpty ? null : items;
  }

  static String _normalize(String raw) {
    return raw
        .replaceAll('％', '%')
        .replaceAllMapped(
          _fullWidthDigit,
          (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFEE0),
        )
        .replaceAll('\r', '\n')
        .replaceAll('、', '\n')
        .replaceAll('，', '\n')
        .replaceAll(',', '\n')
        .replaceAll('；', '\n')
        .replaceAll(';', '\n')
        .trim();
  }

  static String _cleanLabel(String raw) {
    var label = raw.trim();
    while (label.isNotEmpty && _isTrimmable(label.codeUnitAt(0))) {
      label = label.substring(1).trim();
    }
    while (
        label.isNotEmpty && _isTrimmable(label.codeUnitAt(label.length - 1))) {
      label = label.substring(0, label.length - 1).trim();
    }
    return label;
  }

  static bool _isTrimmable(int codeUnit) {
    const trimmable = ['(', ')', '（', '）', '·', '*', '.', '、', ':', '：'];
    return trimmable.contains(String.fromCharCode(codeUnit));
  }
}
