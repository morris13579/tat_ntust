import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 頁面中段的空狀態：圖示比 `EmptyState` 小一號、文字用 `onSurfaceVariant`。
/// 周圍還有標題與另一個區塊時要用這個——整頁級的那張圖疊兩份會像兩個空畫面。
class SectionEmptyState extends StatelessWidget {
  const SectionEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
