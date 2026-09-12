import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 「第 3 節 · 10:20–11:10」那一列，右邊是改時段。
///
/// 節次一定帶時間：沒人記得第七節是幾點。
class ClassroomSectionBar extends StatelessWidget {
  const ClassroomSectionBar({
    super.key,
    required this.section,
    required this.onChange,
  });

  /// 節次索引，與 [sectionTimes] 對齊。
  final int section;

  final VoidCallback onChange;

  /// 「第 3 節 · 10:20–11:10」。索引超出範圍時只給時間，不要讓畫面炸掉。
  static String label(int section) {
    if (section < 0 || section >= sectionTimes.length) return '';
    final time = sectionTimes[section];
    return sprintf(R.current.classroomSectionAt,
        [sectionLabels[section], '${time.start}–${time.end}']);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // 「改時段」不用 TextButton：主題給它的最小高度是 44，整條帶子會被撐到
    // 60 以上，而這只是一行狀態文字。自己包一顆點得到的文字就好。
    return Material(
      color: scheme.primaryContainer,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(LucideIcons.clock, size: 15, color: scheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Text(
                label(section),
                style: context.text.labelLarge
                    ?.copyWith(color: scheme.onPrimaryContainer, height: 1.4),
              ),
            ),
          ),
          InkWell(
            onTap: onChange,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(
                R.current.classroomChangeTime,
                style: context.text.labelLarge
                    ?.copyWith(color: scheme.primary, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
