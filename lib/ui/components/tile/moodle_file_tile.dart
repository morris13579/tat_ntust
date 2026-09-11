import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/ui/components/file_type_icon.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

/// Moodle 檔案的一列：類型 icon、檔名、下載提示。下載本身留給呼叫端，
/// 它才知道要存到哪個課程資料夾。
///
/// 資料夾頁的子資料夾列也走這裡，只是換掉 [leading] 與 [trailing]。
class MoodleFileTile extends StatelessWidget {
  const MoodleFileTile({
    super.key,
    required this.filename,
    this.mimetype = "",
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dimmed = false,
  });

  final String filename;

  /// 論壇附件沒有這個欄位，[FileTypeIcon] 會退回看副檔名。
  final String mimetype;

  /// null 時整列維持單行。
  final String? subtitle;

  /// 預設是依 [filename] / [mimetype] 決定的檔案類型 icon。
  final Widget? leading;

  /// 預設是下載提示。
  final Widget? trailing;

  /// null 時整列不吃點擊，也不會有漣漪——沒有事情可做的列不該假裝可以按。
  final VoidCallback? onTap;

  /// true = 這一列指的東西即將消失（例如儲存後會被移除的繳交檔案）。
  /// 刪除線與淡色一起上：只調淡的話跟「停用」長得一模一樣。
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: TatTokens.iconColumn,
      horizontalTitleGap: 11,
      minVerticalPadding: 8,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TatTokens.radiusButton)),
      leading: leading ??
          FileTypeIcon(filename: filename, mimetype: mimetype, size: 20),
      title: Text(filename,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodyLarge?.copyWith(
              color: dimmed ? scheme.onSurfaceVariant : scheme.onSurface,
              decoration: dimmed ? TextDecoration.lineThrough : null,
              decorationColor: scheme.onSurfaceVariant,
              height: 1.4)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.tabular((text.bodySmall ?? const TextStyle())
                  .copyWith(color: scheme.onSurfaceVariant, height: 1.4))),
      // 下載提示是這一列唯一的動作，用 accent 色：檔名旁邊多一個灰圖示看起來
      // 只是裝飾。細筆畫是為了和左邊的檔案類型圖示同粗。
      trailing: trailing ??
          Icon(LucideIconsThin.download, size: 18, color: scheme.primary),
      onTap: onTap,
    );
  }
}
