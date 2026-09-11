import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 通知頁的空狀態：一個細線收件匣、一行標題、一段說明。
///
/// 不用共用的 `EmptyState`：那一份只有圖示加一行字，而這裡的第二行才是重點
/// ——「這頁平常本來就很空」得說出來，否則使用者會以為是載入失敗。
class NotificationEmptyView extends StatelessWidget {
  const NotificationEmptyView({
    super.key,
    required this.message,
    required this.hint,
  });

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIconsThin.inbox,
                  size: 40, color: scheme.onSurfaceVariant),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 7),
              Text(
                hint,
                textAlign: TextAlign.center,
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
