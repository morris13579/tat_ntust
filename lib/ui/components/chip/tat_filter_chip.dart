import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 篩選用的 chip。
///
/// 選中是 primaryContainer 上的 primary，沒選中是一塊卡片色——**兩者都不描邊，
/// 這份設計裡沒有描邊的元件**。Material 的 `FilterChip` 預設會畫一圈框，跟其餘
/// 畫面格格不入，所以整個 App 一律用這一個。
class TatFilterChip extends StatelessWidget {
  const TatFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 少數需要圖示的 chip（例如「篩選」）。其餘只有文字。
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Material(
      color: selected ? scheme.primaryContainer : context.tokens.card,
      borderRadius: BorderRadius.circular(TatTokens.radiusButton),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.text.labelLarge
                    ?.copyWith(color: foreground, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
