import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 月曆的一格：日期數字，底下是「這天有東西」的圓點。
///
/// 今天是**填滿的圓角方塊配反相文字**，不是一圈外框——外框在有底色的日子上
/// 認不出來，填滿才一眼分得出來。點的顏色分兩種（學校行事曆／作業截止），
/// 圖例就畫在月曆下面。
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.day,
    this.isToday = false,
    this.isSelected = false,
    this.hasSchoolEvent = false,
    this.hasDeadline = false,
    this.enabled = true,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool hasSchoolEvent;
  final bool hasDeadline;
  final bool enabled;

  static const double _dotSize = 5;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tokens = context.tokens;

    final Color? fill = isToday
        ? scheme.primary
        : isSelected
            ? scheme.primaryContainer
            : null;
    final Color foreground = isToday
        ? scheme.onPrimary
        : isSelected
            ? scheme.onPrimaryContainer
            : enabled
                ? scheme.onSurface
                : scheme.onSurfaceVariant;
    // 填滿的今天上面，兩種點都要反相才看得見，這時顏色不再帶語意，
    // 語意留給下面的清單。
    final Color schoolDot = isToday ? scheme.onPrimary : scheme.primary;
    final Color deadlineDot = isToday ? scheme.onPrimary : tokens.warning;

    return Container(
      // 1px 邊界 x2 = 設計稿上格子之間的 2px 縫。
      margin: const EdgeInsets.all(1),
      decoration: fill == null
          ? null
          : BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(10),
            ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: AppTypography.tabular(context.text.bodyLarge!).copyWith(
              color: foreground,
              height: 1.2,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: _dotSize,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSchoolEvent) _Dot(color: schoolDot),
                if (hasSchoolEvent && hasDeadline) const SizedBox(width: 3),
                if (hasDeadline) _Dot(color: deadlineDot),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: CalendarDayCell._dotSize,
        height: CalendarDayCell._dotSize,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
