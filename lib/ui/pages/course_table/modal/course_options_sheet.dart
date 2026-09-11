import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

/// 課表標頭上「⋮」開出來的選項。
enum CourseTableOption {
  favorite,
  importCourse,
  scan,
  share,
  exportImage,
  androidWidget
}

/// 課表選項。回傳 null 代表沒選。
///
/// [canImport] 為 false（正在看別人的課表）時不給加課：加進去的課會存回
/// 對方那份快取。
Future<CourseTableOption?> showCourseOptionsSheet({
  required BuildContext context,
  required bool canImport,
}) =>
    showTatContentSheet<CourseTableOption>(
      context: context,
      title: R.current.courseTableOptions,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OptionRow(
            icon: LucideIcons.layers2,
            label: R.current.switchTable,
            supporting: R.current.switchTableHint,
            value: CourseTableOption.favorite,
          ),
          if (canImport)
            _OptionRow(
              icon: LucideIcons.plus,
              label: R.current.importCourse,
              supporting: R.current.importCourseHint,
              value: CourseTableOption.importCourse,
            ),
          _OptionRow(
            icon: LucideIcons.scanLine,
            label: R.current.scanTableTitle,
            supporting: R.current.scanTableHint,
            value: CourseTableOption.scan,
          ),
          const Divider(height: 17),
          _OptionRow(
            icon: LucideIcons.share2,
            label: R.current.shareTableTitle,
            supporting: R.current.shareTableHint,
            value: CourseTableOption.share,
          ),
          _OptionRow(
            icon: LucideIcons.download,
            label: R.current.exportImage,
            supporting: R.current.exportImageHint,
            value: CourseTableOption.exportImage,
          ),
          if (GetPlatform.isAndroid) ...[
            const Divider(height: 17),
            _OptionRow(
              icon: LucideIcons.layoutGrid,
              label: R.current.setAsAndroidWeight,
              value: CourseTableOption.androidWidget,
            ),
          ],
        ],
      ),
    );

/// 帶副標的一列。`showTatActionSheet` 的列只有標籤，這裡三列各自要一句話
/// 說明它會做什麼，所以自己排。
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.value,
    this.supporting,
  });

  final IconData icon;
  final String label;
  final String? supporting;
  final CourseTableOption value;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: TatTokens.iconColumn,
              child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: context.text.bodyLarge
                        ?.copyWith(height: 1.5, color: scheme.onSurface),
                  ),
                  if (supporting != null)
                    Text(
                      supporting!,
                      style: context.text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
