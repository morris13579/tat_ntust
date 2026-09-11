import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 月曆下面的圖例。兩種圓點沒有這一行就只是兩個不明所以的顏色。
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendItem(
          color: context.scheme.primary,
          label: R.current.calendarSourceSchool,
        ),
        const SizedBox(width: 16),
        _LegendItem(
          color: context.tokens.warning,
          label: R.current.calendarSourceDeadline,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: context.text.bodySmall
              ?.copyWith(color: context.scheme.onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }
}
