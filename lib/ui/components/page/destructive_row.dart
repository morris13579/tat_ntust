import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 破壞性動作的那一列：紅色圖示加紅字。
///
/// 頭貼選單、討論區貼文選單、作業溢位選單原本各抄了一份一模一樣的，
/// 顏色一旦有人改一處就會三處不一致。
class DestructiveRow extends StatelessWidget {
  const DestructiveRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.enabled = true,
  }) : _compact = false;

  /// 給 [PopupMenuItem] 用的窄版：點擊、內距與停用態都由選單管，
  /// 這裡只出圖示與紅字。
  const DestructiveRow.menuItem({
    super.key,
    required this.icon,
    required this.label,
  })  : subtitle = null,
        onTap = null,
        enabled = true,
        _compact = true;

  final IconData icon;
  final String label;

  /// 停用時說明為什麼按不下去。窄版沒有這一行。
  final String? subtitle;

  final VoidCallback? onTap;
  final bool enabled;

  final bool _compact;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    if (_compact) {
      return Row(
        children: [
          Icon(icon, size: 18, color: scheme.error),
          const SizedBox(width: 12),
          Text(
            label,
            style: context.text.labelLarge?.copyWith(color: scheme.error),
          ),
        ],
      );
    }

    // 停用時交回 ListTile 的停用色：紅字是在請人小心，而一個按不下去的
    // 動作沒什麼好小心的。
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: enabled ? scheme.error : null),
      title: Text(
        label,
        style: enabled
            ? context.text.bodyLarge?.copyWith(color: scheme.error)
            : null,
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: onTap,
    );
  }
}
