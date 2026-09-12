import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 一間教室那一天的明細。
///
/// 一整天檢視刻意不寫課名——那不是找位子的人要的東西。但「這一格是什麼課」
/// 偶爾還是想知道，所以點一列開這一張，而不是把課名塞回格子裡。
Future<void> showClassroomRoomSheet({
  required BuildContext context,
  required ClassroomRowJson room,
  required int section,
}) {
  return showTatContentSheet<void>(
    context: context,
    title: room.name,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < room.slots.length; i++)
          _SlotRow(slot: room.slots[i], index: i, isNow: i == section),
      ],
    ),
  );
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.index,
    required this.isNow,
  });

  final ClassroomSlotJson slot;
  final int index;

  /// 正在查的那一節。標出來，使用者才對得上剛剛看的是哪一格。
  final bool isNow;

  /// 每一列固定高度。
  ///
  /// 課名與老師如果照內容撐高，有老師的列兩行、沒老師的列一行，十四列會高高
  /// 低低像沒對齊的表格。老師改成同一行右側的一欄，行高就一致了。
  static const double _height = 40;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final time = sectionTimes[index];
    final free = slot.isFree;
    return Container(
      height: _height,
      color: isNow ? scheme.primaryContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              '${sectionLabels[index]}  ${time.start}',
              style: context.text.labelMedium?.copyWith(
                  height: 1.35,
                  color: isNow
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              free
                  ? R.current.classroomFreeCell
                  : (slot.course.isEmpty
                      ? R.current.classroomLegendBooked
                      : slot.course),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                height: 1.35,
                color: free ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
          ),
          if (slot.teacher.isNotEmpty) ...[
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                slot.teacher,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: context.text.bodySmall?.copyWith(
                    height: 1.35, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
