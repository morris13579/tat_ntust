import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';

/// 課表上一個空堂格的選單。回傳 true 代表使用者要去找空教室。
///
/// 空堂格原本沒有任何點擊行為——`showCourseCellSheet` 需要 `CourseInfoJson`，
/// 而空堂沒有。這一份是空堂專用的。
///
/// **時間與星期都已經在畫面上**，所以從這裡進空教室不用再選任何條件，直接
/// 開在那一節。上面那一段先把「你點的是哪一格」講清楚，使用者才知道待會
/// 查的是什麼。
Future<bool> showEmptyCellSheet({
  required BuildContext context,
  required DateTime date,
  required int section,
}) async {
  final time = sectionTimes[section];
  final result = await showTatContentSheet<bool>(
    context: context,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 星期取自真正要查的那一天，不是課表表頭那個「一」——使用者
              // 待會查的是最近的那個週一，講清楚是哪一天比較不會誤會。
              Text(
                '${DateFormat.E().format(date)} '
                '${sprintf(R.current.classroomSectionLabel, [
                      sectionLabels[section]
                    ])}',
                style: context.text.titleMedium?.copyWith(height: 1.3),
              ),
              const SizedBox(height: 2),
              Text(
                '${time.start}–${time.end} · ${R.current.classroomFreeCell}',
                style: context.text.bodySmall?.copyWith(
                    height: 1.35, color: context.scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              constraints:
                  const BoxConstraints(minHeight: TatTokens.heightRow),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(LucideIcons.doorOpen,
                      size: 20, color: context.scheme.onSurfaceVariant),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(R.current.classroomFromCourseTable,
                        style: context.text.bodyLarge),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
