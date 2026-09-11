import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/util/rich_editor_bridge_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:sprintf/sprintf.dart';

/// 所見即所得編輯器的工具列。**完全沒有 WebView**，所以它是這整個功能裡
/// 唯一可以用 widget test 蓋滿的一塊。
///
/// 這一排照官方 Moodle App 的 `rich-text-editor`：粗體 / 斜體 / 底線 /
/// 刪除線 / 內文 / h3 / h4 / h5 / 項目符號 / 編號 / 清除格式，再加一顆原始碼
/// 切換。**沒有插入圖片**——官方 App 也沒有，`mod_forum` 那條路只能保留貼文
/// 原有的圖片，加不了新的。
///
/// 原始碼那一顆釘在右牆邊不跟著捲：它是模式切換不是第十二個格式鈕，而在
/// 402pt 的手機上它正好是會被捲出畫面的那一顆。兩側的漸層加箭頭則是唯一
/// 的線索——沒有它，第一次用的人不會知道後面還有東西。
class MoodleRichEditorToolbar extends StatefulWidget {
  const MoodleRichEditorToolbar({
    super.key,
    required this.active,
    required this.onCommand,
    required this.sourceMode,
    required this.onToggleSource,
    this.enabled = true,
    this.trailing = const <Widget>[],
    this.dense = false,
  });

  /// 目前游標處生效的格式，值是 [RichEditorBridgeUtils.tokenOf] 的字面值。
  final Set<String> active;

  final ValueChanged<EditorCommand> onCommand;

  /// 原始碼模式：格式鈕全部停用（在原始碼上套粗體沒有意義）。
  final bool sourceMode;
  final VoidCallback onToggleSource;

  /// 編輯器還沒準備好、或正在送出時整排停用。
  final bool enabled;

  /// 釘在最右邊、不跟著捲的額外動作（打字時的附件與收鍵盤）。這一列的高度是
  /// 固定的 40，多放兩顆不會多吃一點高度——實測字級 3.0、寬 320 仍然是 64。
  final List<Widget> trailing;

  /// 卡片上下的內距讓出 16。給「鍵盤把高度壓到連編輯面都守不住」的版面用，
  /// **按鈕本身一點都沒縮**：40 的觸控範圍原封不動，讓開的只有留白。
  final bool dense;

  /// 這一列的高度是固定的，量得到也算得出來，所以版面那一邊可以直接拿它去
  /// 分高度，不必等 layout 回報。
  static const double height = 64;
  static const double denseHeight = 48;

  static IconData _iconOf(EditorCommand c) => switch (c) {
        EditorCommand.bold => LucideIcons.bold,
        EditorCommand.italic => LucideIcons.italic,
        EditorCommand.underline => LucideIcons.underline,
        EditorCommand.strikeThrough => LucideIcons.strikethrough,
        EditorCommand.paragraph => LucideIcons.pilcrow,
        EditorCommand.heading3 => LucideIcons.heading3,
        EditorCommand.heading4 => LucideIcons.heading4,
        EditorCommand.heading5 => LucideIcons.heading5,
        EditorCommand.unorderedList => LucideIcons.list,
        EditorCommand.orderedList => LucideIcons.listOrdered,
        EditorCommand.removeFormat => LucideIcons.removeFormatting,
      };

  static String labelOf(EditorCommand c) => switch (c) {
        EditorCommand.bold => R.current.forumEditorBold,
        EditorCommand.italic => R.current.forumEditorItalic,
        EditorCommand.underline => R.current.forumEditorUnderline,
        EditorCommand.strikeThrough => R.current.forumEditorStrikethrough,
        EditorCommand.paragraph => R.current.forumEditorParagraph,
        EditorCommand.heading3 => sprintf(R.current.forumEditorHeading, ['3']),
        EditorCommand.heading4 => sprintf(R.current.forumEditorHeading, ['4']),
        EditorCommand.heading5 => sprintf(R.current.forumEditorHeading, ['5']),
        EditorCommand.unorderedList => R.current.forumEditorBulletList,
        EditorCommand.orderedList => R.current.forumEditorNumberedList,
        EditorCommand.removeFormat => R.current.forumEditorClearFormat,
      };

  @override
  State<MoodleRichEditorToolbar> createState() =>
      _MoodleRichEditorToolbarState();
}

class _MoodleRichEditorToolbarState extends State<MoodleRichEditorToolbar> {
  final _scroll = ScrollController();
  bool _atStart = true;
  bool _atEnd = false;

  @override
  void initState() {
    super.initState();
    // ScrollMetricsNotification 在某些情況下不會為第一次 layout 送出來，
    // 補一發才不會在寬螢幕上留著一個永遠不會消失的箭頭。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _sync(_scroll.position);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _sync(ScrollMetrics m) {
    final start = m.extentBefore <= 0.5;
    final end = m.extentAfter <= 0.5;
    if (start != _atStart || end != _atEnd) {
      setState(() {
        _atStart = start;
        _atEnd = end;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(child: _strip(context, scheme)),
          const VerticalDivider(width: 9, indent: 8, endIndent: 8),
          _button(
            icon: LucideIcons.codeXml,
            tooltip: R.current.forumEditorSource,
            selected: widget.sourceMode,
            onPressed: widget.enabled ? widget.onToggleSource : null,
            scheme: scheme,
          ),
          ...widget.trailing,
        ],
      ),
    );
    return widget.dense ? SectionCard.compact([row]) : SectionCard([row]);
  }

  Widget _strip(BuildContext context, ColorScheme scheme) => Stack(
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) => _sync(n.metrics),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => _sync(n.metrics),
              child: ListView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                children: [
                  for (final command in EditorCommand.values)
                    _button(
                      icon: MoodleRichEditorToolbar._iconOf(command),
                      tooltip: MoodleRichEditorToolbar.labelOf(command),
                      selected: widget.active
                          .contains(RichEditorBridgeUtils.tokenOf(command)),
                      onPressed: (widget.enabled && !widget.sourceMode)
                          ? () => widget.onCommand(command)
                          : null,
                      scheme: scheme,
                    ),
                ],
              ),
            ),
          ),
          Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _scrim(context, scheme, trailing: false, show: !_atStart)),
          Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _scrim(context, scheme, trailing: true, show: !_atEnd)),
        ],
      );

  /// key 是給測試讀透明度用的：AnimatedOpacity 一直都在樹上，只靠
  /// `find.byIcon` 會一律比得到，測起來是假綠。
  Widget _scrim(BuildContext context, ColorScheme scheme,
      {required bool trailing, required bool show}) {
    final fill = SectionCard.fill(context);
    return IgnorePointer(
      child: AnimatedOpacity(
        key: ValueKey(trailing ? 'toolbar-scrim-end' : 'toolbar-scrim-start'),
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 28,
          alignment: trailing ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: trailing ? Alignment.centerLeft : Alignment.centerRight,
              end: trailing ? Alignment.centerRight : Alignment.centerLeft,
              colors: [fill.withValues(alpha: 0), fill],
            ),
          ),
          child: Icon(
              trailing ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
              size: 14,
              color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _button({
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback? onPressed,
    required ColorScheme scheme,
  }) =>
      IconButton(
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        isSelected: selected,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: selected ? scheme.secondaryContainer : null,
          foregroundColor: selected ? scheme.onSecondaryContainer : null,
        ),
      );
}
