import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 設定類清單的一列。更多、關於、設定三頁原本各抄了一份一模一樣的。
///
/// 給了 [index] 與 [length] 就會照群組位置決定圓角，讓連續幾列看起來是一組。
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingValue,
    this.showChevron = true,
    this.destructive = false,
    required this.onTap,
    this.index,
    this.length,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// 右邊顯示目前的值（語言、主題、版本）。
  final String? trailingValue;

  final bool showChevron;
  final bool destructive;
  final VoidCallback onTap;
  final int? index;
  final int? length;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final foreground = destructive ? scheme.error : scheme.onSurface;
    final borderRadius = (index != null && length != null)
        ? UIUtils.getBorderRadius(index!, length!)
        : null;

    return Material(
      color: context.tokens.card,
      borderRadius: borderRadius ?? BorderRadius.circular(TatTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: TatTokens.heightRow),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: destructive ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style:
                          context.text.bodyLarge?.copyWith(color: foreground),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: context.text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (trailingValue != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    trailingValue!,
                    style: context.text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (showChevron)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
