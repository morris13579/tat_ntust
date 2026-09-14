import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';

/// 課表上空堂格的字。Flutter 的 `showEmptyCellSheet` 與原生版共用這一份。
class EmptySlotText {
  EmptySlotText._();

  /// 「週一 第 3 節」。星期取自真正要查的那一天，不是課表表頭那個「一」——使用者待會查的是
  /// 最近的那個週一，講清楚是哪一天比較不會誤會。
  static String title(DateTime date, int section) =>
      '${DateFormat.E().format(date)} '
      '${sprintf(R.current.classroomSectionLabel, [sectionLabels[section]])}';

  /// 「10:20–11:10 · 空堂」。
  static String subtitle(int section) {
    final time = sectionTimes[section];
    return '${time.start}–${time.end} · ${R.current.classroomFreeCell}';
  }
}
