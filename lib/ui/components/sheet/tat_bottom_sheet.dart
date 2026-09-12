import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 動作清單的一列。
class TatSheetItem<T> {
  const TatSheetItem({
    required this.icon,
    required this.label,
    required this.value,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final T value;

  /// 破壞性動作靠 error 色自己站出來，其餘各列一律 onSurfaceVariant——
  /// 三列都是重音色的話就沒有一列是重點。
  final bool destructive;
}

/// 單選清單的一個選項。
class TatSheetOption<T> {
  const TatSheetOption({
    required this.label,
    this.supporting,
    required this.value,
    this.icon,
  });

  final String label;
  final String? supporting;
  final T value;

  /// 左側圖示。null 就不佔那一欄——大多數單選清單（學期、語言）的選項是同
  /// 一類東西，給每一列一個圖示只是重複。信箱的資料夾不一樣：收件匣與其餘
  /// 資料夾是兩種東西。
  final IconData? icon;
}

/// 動作清單。沒有標題、沒有分隔線、也沒有取消列——下滑與點遮罩都能關。
Future<T?> showTatActionSheet<T>({
  required BuildContext context,
  required List<TatSheetItem<T>> items,
}) =>
    _showSheet<T>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items) _ActionRow<T>(item: item),
        ],
      ),
    );

/// 單選清單。點了就生效、選單自己關掉——選項本身就是決定，不需要「確定」。
Future<T?> showTatSingleSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<TatSheetOption<T>> options,
  T? selected,
  bool showClose = false,
  bool tabularFigures = false,
}) =>
    _showSheet<T>(
      context: context,
      title: title,
      showClose: showClose,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in options)
            TatSheetOptionRow<T>(
              option: option,
              isSelected: option.value == selected,
              tabularFigures: tabularFigures,
              onTap: () => Navigator.pop(context, option.value),
            ),
        ],
      ),
    );

/// 內容型。有內容也有動作時就不是清單，版面交給呼叫端自己排。
Future<T?> showTatContentSheet<T>({
  required BuildContext context,
  String? title,
  bool showClose = false,
  required WidgetBuilder builder,
}) =>
    _showSheet<T>(
      context: context,
      title: title,
      showClose: showClose,
      builder: builder,
    );

/// 三種選單共用的殼：最大高 72%、底部留白 26 + safe area、可下滑可點遮罩關閉。
///
/// 回傳 `null` 代表沒選。選單沒有「預設答案」，關掉不會讓呼叫端誤會使用者拒絕了。
Future<T?> _showSheet<T>({
  required BuildContext context,
  String? title,
  bool showClose = false,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    // 不用內建的把手：它會保留 48 的可點高度，上緣硬是多出一大塊留白。
    // 規格是 36x4、上方 10，自己畫比較準。
    showDragHandle: false,
    constraints: BoxConstraints(
      maxHeight:
          MediaQuery.sizeOf(context).height * TatTokens.sheetMaxHeightFactor,
    ),
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DragHandle(),
          if (title != null || showClose)
            _SheetHeader(title: title, showClose: showClose),
          Flexible(child: SingleChildScrollView(child: builder(context))),
          const SizedBox(height: 26),
        ],
      ),
    ),
  );
}

/// 36x4 的把手。可拖曳的視覺提示，不是按鈕。
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: context.scheme.outlineVariant,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.showClose});

  final String? title;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, showClose ? 8 : 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title ?? '', style: context.text.titleLarge),
          ),
          if (showClose)
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(LucideIcons.x),
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}

class _ActionRow<T> extends StatelessWidget {
  const _ActionRow({required this.item});

  final TatSheetItem<T> item;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final foreground = item.destructive ? scheme.error : scheme.onSurface;
    return InkWell(
      onTap: () => Navigator.pop(context, item.value),
      child: Container(
        constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: TatTokens.iconColumn,
              child: Icon(
                item.icon,
                size: 20,
                color:
                    item.destructive ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: context.text.bodyLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 單選清單的一列。選單與對話框共用，兩邊看起來才是同一個東西。
class TatSheetOptionRow<T> extends StatelessWidget {
  const TatSheetOptionRow({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
    this.tabularFigures = false,
  });

  final TatSheetOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;

  /// 整欄都是數字時（歷年學期）用等寬數字，位數才對得齊。
  final bool tabularFigures;

  /// 選中的那一列不再加粗：底色、打勾與文字顏色已經是三個訊號，再加一個
  /// 字重只會讓整張選單看起來吵。
  TextStyle? _labelStyle(BuildContext context) {
    final base = context.text.bodyLarge?.copyWith(height: 1.45);
    if (base == null || !tabularFigures) return base;
    return AppTypography.tabular(base);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // 選中的一列是一塊圓角底色，左右各內縮 8——滿版反白會讓它看起來像被
    // 游標壓著，而不是「這一個就是目前的值」。
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: isSelected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(TatTokens.radiusButton),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                if (option.icon != null) ...[
                  Icon(
                    option.icon,
                    size: 20,
                    color: isSelected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.label,
                        style: _labelStyle(context)?.copyWith(
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                      if (option.supporting != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            option.supporting!,
                            style: context.text.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                SizedBox(
                  width: 22,
                  child: isSelected
                      ? Icon(LucideIcons.check,
                          size: 20, color: scheme.onPrimaryContainer)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
