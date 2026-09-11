import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 行事曆頁清單的一列：圖示、標題，底下一行「來源 · 時間 · 剩餘」。
///
/// 一組相連的列不是一張帶分隔線的卡：每一列自己收圓角、彼此留 2px 的縫，
/// 跟設定頁那幾組一致。
class CalendarEventRow extends StatelessWidget {
  const CalendarEventRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.subtitleKey,
    this.onTap,
    required this.index,
    required this.length,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;

  /// 逾期那幾列要用 error 色，其餘留 null 走 onSurfaceVariant。
  final Color? subtitleColor;

  final Key? subtitleKey;

  final VoidCallback? onTap;

  final int index;
  final int length;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final subtitle = this.subtitle;
    final borderRadius = UIUtils.getBorderRadius(index, length);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    key: subtitleKey,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // 日期與時間要上下對齊，這一行走等寬數字。
                    style: AppTypography.tabular(text.bodySmall!).copyWith(
                      color: subtitleColor ?? scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Container(
        decoration: BoxDecoration(
          color: context.tokens.card,
          borderRadius: borderRadius,
        ),
        child: content,
      );
    }
    return Material(
      color: context.tokens.card,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
