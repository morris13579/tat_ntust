import 'package:flutter_app/debug/log/log.dart';
import 'package:icalendar_parser/icalendar_parser.dart';

/// 學校行事曆 .ics 的解析。App 的行事曆頁與原生版共用。
class SchoolCalendarUtils {
  SchoolCalendarUtils._();

  /// 每一天（UTC 的那一天）有哪些事。
  static Map<DateTime, List<String>> parse(List<String> lines) {
    final events = <DateTime, List<String>>{};
    for (final entry in ICalendar.fromLines(lines).data) {
      if (!entry.containsKey("dtstart") || !entry.containsKey("summary")) {
        continue;
      }
      // 單筆解析失敗只跳過該筆，否則例外會讓畫面停在半份行事曆。
      try {
        final IcsDateTime start = entry["dtstart"];
        final dt = DateTime.parse(start.dt);
        final day = DateTime.utc(dt.year, dt.month, dt.day);
        final String summary = entry["summary"];
        for (final raw in summary.split("  ")) {
          // 剝掉開頭的編號前綴。不可換成固定長度切割：編號可能是兩位數。
          final item =
              raw.replaceAll(" ", "").replaceFirst(RegExp(r'^\d+[.、,:]?'), '');
          if (item.isEmpty) continue;
          events.putIfAbsent(day, () => []).add(item);
        }
      } catch (e, stack) {
        Log.eWithStack(e.toString(), stack);
      }
    }
    return events;
  }
}
