import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

enum NoticeKind { error, warning, info }

/// 釘在內容區頂端的提示條：不浮動、不自動消失、可以帶一個動作。
///
/// 取代置頂的紅底 snackbar。它是版面裡的一塊，使用者捲得回來，也才有地方
/// 放「重試」這種出口。
class NoticeBar extends StatelessWidget {
  const NoticeBar({
    super.key,
    required this.message,
    this.kind = NoticeKind.info,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String message;
  final NoticeKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 蓋掉種類預設的圖示。舊資料橫幅用 history 比 info 準確。
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tokens = context.tokens;
    // info 刻意用中性色而不是藍：它多半在講「你看到的是舊資料」，
    // 那不是一件需要搶眼的事。
    final (background, foreground) = switch (kind) {
      NoticeKind.error => (scheme.errorContainer, scheme.onErrorContainer),
      NoticeKind.warning => (tokens.warningContainer, tokens.warning),
      NoticeKind.info => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant
        ),
    };
    final defaultIcon = switch (kind) {
      NoticeKind.error => LucideIcons.circleAlert,
      NoticeKind.warning => LucideIcons.triangleAlert,
      NoticeKind.info => LucideIcons.info,
    };

    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon ?? defaultIcon, size: 16, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: context.text.bodySmall?.copyWith(color: foreground),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: foreground),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
