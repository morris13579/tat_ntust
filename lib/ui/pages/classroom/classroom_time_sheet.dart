import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/src/util/classroom_availability.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:intl/intl.dart';

/// 使用者選好的時段。
typedef ClassroomTime = ({DateTime date, int section});

/// 改時段。
///
/// 日期只給往後兩週：借用系統的表也只排到那裡，再往後選只會拿到空的一天。
/// 節次一定帶時間，因為沒人記得第七節是幾點。「回到現在」是唯一的離開路徑，
/// 不用另外找。
Future<ClassroomTime?> showClassroomTimeSheet({
  required BuildContext context,
  required DateTime date,
  required int section,
  DateTime? now,
}) {
  return showTatContentSheet<ClassroomTime>(
    context: context,
    builder: (context) => _ClassroomTimeSheet(
      date: date,
      section: section,
      now: now ?? DateTime.now(),
    ),
  );
}

/// 日期清單的長度。借用系統的課表排到兩週後，再遠也是空的。
const int _dayCount = 14;

class _ClassroomTimeSheet extends StatefulWidget {
  const _ClassroomTimeSheet({
    required this.date,
    required this.section,
    required this.now,
  });

  final DateTime date;
  final int section;
  final DateTime now;

  @override
  State<_ClassroomTimeSheet> createState() => _ClassroomTimeSheetState();
}

class _ClassroomTimeSheetState extends State<_ClassroomTimeSheet> {
  late DateTime _date = widget.date;
  late int _section = widget.section;

  List<DateTime> get _days {
    final today = DateTime(widget.now.year, widget.now.month, widget.now.day);
    return [
      for (var i = 0; i < _dayCount; i++) today.add(Duration(days: i)),
    ];
  }

  /// 節次一列放幾個。十四節分成 4 / 4 / 4 / 2，最後一列補空格位把寬度撐住，
  /// 免得剩下兩個按鈕各自變寬、和上面幾列對不齊。
  static const int _sectionsPerRow = 4;

  /// 日期一次露幾格。多的往右捲——借用系統的表排到兩週後，一次全攤開會把
  /// 選單推得太長。
  static const int _daysPerRow = 5;

  static const double _gap = 8;

  /// 內容左右內縮。標題、格子與底部按鈕共用同一個值才對得齊。
  static const double _inset = 20;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 右邊留 8：「回到現在」自己還有 12 的內距，兩者相加才等於 _inset，
      // 文字尾端就和左邊的標題對齊。
      padding: const EdgeInsets.fromLTRB(_inset, 0, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(R.current.classroomChangeTime,
                    style: context.text.titleLarge?.copyWith(height: 1.3)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  final (date, section) =
                      ClassroomAvailability.nowSection(widget.now);
                  Navigator.pop(context, (date: date, section: section));
                },
                child: Text(R.current.classroomBackToNow),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: _inset - 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _label(context, R.current.classroomDate),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // 寬度算到剛好露出 [_daysPerRow] 格，捲起來時邊緣不會卡著
                    // 半格。
                    final width = (constraints.maxWidth -
                            _gap * (_daysPerRow - 1)) /
                        _daysPerRow;
                    return SizedBox(
                      height: 66,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _days.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: _gap),
                        itemBuilder: (context, index) => SizedBox(
                          width: width,
                          child: _dayChip(context, _days[index]),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _label(context, R.current.classroomSection),
                for (var start = 0;
                    start < sectionTimes.length;
                    start += _sectionsPerRow) ...[
                  if (start > 0) const SizedBox(height: _gap),
                  SizedBox(
                    height: 58,
                    child: Row(
                      children: [
                        for (var i = start;
                            i < start + _sectionsPerRow;
                            i++) ...[
                          if (i > start) const SizedBox(width: _gap),
                          Expanded(
                            child: i < sectionTimes.length
                                ? _sectionChip(context, i)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(TatTokens.radiusCard),
                      ),
                    ),
                    onPressed: () => Navigator.pop(
                        context, (date: _date, section: _section)),
                    child: Text(R.current.classroomApplyTime),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: context.text.bodyMedium?.copyWith(
                height: 1.3, color: context.scheme.onSurfaceVariant)),
      );

  Widget _dayChip(BuildContext context, DateTime day) => _chip(
        context,
        selected: day == _date,
        onTap: () => setState(() => _date = day),
        top: DateFormat.E().format(day),
        bottom: DateFormat.Md().format(day),
      );

  Widget _sectionChip(BuildContext context, int index) => _chip(
        context,
        selected: index == _section,
        onTap: () => setState(() => _section = index),
        top: sectionLabels[index],
        bottom: sectionTimes[index].start,
        emphasiseTop: true,
      );

  /// 上面一行是代號、下面一行是時間，兩種 chip 共用同一個形狀。
  ///
  /// **沒選中的是白底描邊，不是灰底實心。** 選單本身的底色就是
  /// `tokens.card`，不描邊的話整排按鈕會只剩被選中的那一顆看得見。這是全
  /// App 唯一描邊的元件，因為它是唯一一個畫在同色卡片上的按鈕群。
  Widget _chip(
    BuildContext context, {
    required bool selected,
    required VoidCallback onTap,
    required String top,
    required String bottom,
    bool emphasiseTop = false,
  }) {
    final scheme = context.scheme;
    final onChip = selected ? scheme.onPrimary : scheme.onSurface;
    final onChipMuted = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(TatTokens.radiusCard);
    return Material(
      color: selected ? scheme.primary : context.tokens.card,
      clipBehavior: Clip.antiAlias,
      // 只能給 shape 或 borderRadius 其中一個，兩個都給 Material 會在
      // 執行期斷言失敗。描邊要走 shape，所以圓角也一起交給它。
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: selected
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                top,
                style: (emphasiseTop
                        ? context.text.titleMedium
                        : context.text.labelMedium)
                    ?.copyWith(
                        height: 1.2,
                        color: emphasiseTop ? onChip : onChipMuted),
              ),
              const SizedBox(height: 2),
              Text(
                bottom,
                style: (emphasiseTop
                        ? context.text.labelSmall
                        : context.text.titleMedium)
                    ?.copyWith(
                        height: 1.2,
                        color: emphasiseTop ? onChipMuted : onChip),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
