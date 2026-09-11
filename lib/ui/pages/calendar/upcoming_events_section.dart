import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/upcoming_event_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/section_empty_state.dart';
import 'package:flutter_app/ui/pages/calendar/components/calendar_event_row.dart';
import 'package:flutter_app/ui/pages/calendar/components/section_count_label.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

/// 行事曆頁底部的「待辦」區塊：所有課程的截止事項。
///
/// 分組標題是「待辦 · 本週」這種寫法，時間愈近的在上面；「之後」再按月份切開
/// （本月剩下的部分、下個月……），不然三個月的截止日會全部擠在同一組。
/// 不可 import error_page / route_utils，見 docs/ARCHITECTURE.md「UI 慣例」。
class UpcomingEventsSection extends StatelessWidget {
  const UpcomingEventsSection({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onOpen,
    this.first = true,
    this.clock = DateTime.now,
  });

  /// null 代表載入中。
  final Rx<Result<List<MoodleActionEvent>>?> state;

  final Future<void> Function() onRetry;

  final Future<void> Function(MoodleActionEvent event) onOpen;

  /// 這一塊是不是整頁的第一塊。上面已經有別的區塊時要傳 false：第一個組標題
  /// 用的是「頁首」的窄上距，留著的話兩塊之間會比組內的標題到清單還要擠。
  final bool first;

  /// 「現在」。測試注入固定的時間，分組才可預期。
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = state.value?.dataOrNull;
      // 有資料時每一組自己帶標題（「待辦 · 本週」），再擺一個「待辦」大標
      // 就重複了；載入中／失敗／空的時候才需要那一行說明這塊是什麼。
      final showTitle = data == null || data.isEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitle)
            SectionHeader(title: R.current.upcomingEvents, first: first),
          ResultView<List<MoodleActionEvent>>(
            shrinkWrap: true,
            state: state,
            onRetry: onRetry,
            errorBuilder: (message) =>
                InlineErrorView(message: message, onRetry: onRetry),
            builder: (events) => _buildSections(context, events),
          ),
        ],
      );
    });
  }

  Widget _buildSections(BuildContext context, List<MoodleActionEvent> events) {
    // 分組在 build 時依注入的時鐘重算，Stale 的舊快取也會落在正確的組。
    final now = clock();
    final sections = _sectionsOf(events, now);
    if (sections.isEmpty) return const _Empty();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++)
          _buildSection(context, sections[i], now, first: first && i == 0),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    _Section section,
    DateTime now, {
    required bool first,
  }) {
    final events = section.events;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '${R.current.upcomingEvents} · ${section.label}',
          trailing: SectionCountLabel(events.length),
          first: first,
        ),
        for (var i = 0; i < events.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _buildRow(context, events[i], section.bucket, now,
              index: i, length: events.length),
        ],
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    MoodleActionEvent event,
    DeadlineBucket bucket,
    DateTime now, {
    required int index,
    required int length,
  }) {
    final scheme = context.scheme;
    final overdue = bucket == DeadlineBucket.overdue;
    // 圖示顏色就是急迫程度：逾期紅、今天與本週用警示色、更遠的就淡下來。
    final iconColor = overdue
        ? scheme.error
        : (bucket == DeadlineBucket.today || bucket == DeadlineBucket.thisWeek)
            ? context.tokens.warning
            : scheme.onSurfaceVariant;
    return CalendarEventRow(
      icon: _iconFor(event.modulename),
      iconColor: iconColor,
      title: event.title,
      subtitle: _subtitleOf(event, bucket, now),
      subtitleColor: overdue ? scheme.error : null,
      subtitleKey: ValueKey('due-${event.id}'),
      onTap: () => onOpen(event),
      index: index,
      length: length,
    );
  }

  /// 「課名 · 9月11日 15:30 · 剩 4 天」。站台事件沒有課名就少掉那一段；
  /// 剩餘時間只有近在眼前的那幾組才有意義，遠的只寫日期。
  String _subtitleOf(
      MoodleActionEvent event, DeadlineBucket bucket, DateTime now) {
    final parts = <String>[];
    final course = UpcomingEventUtils.courseLabelOf(event);
    if (course != null && course.trim().isNotEmpty) parts.add(course);
    parts.add(_formatDue(event.dueTime, now));
    final remaining = _remainingOf(event.dueTime, bucket, now);
    if (remaining != null) parts.add(remaining);
    return parts.join(' · ');
  }

  /// 跨年才補年份：同一年寫年份只是佔位置。
  static String _formatDue(DateTime due, DateTime now) =>
      (due.year == now.year ? DateFormat.MMMd() : DateFormat.yMMMd())
          .add_Hm()
          .format(due);

  static String? _remainingOf(
      DateTime due, DeadlineBucket bucket, DateTime now) {
    if (bucket != DeadlineBucket.today && bucket != DeadlineBucket.thisWeek) {
      return null;
    }
    final left = due.difference(now);
    if (left.isNegative) return null;
    if (left.inHours < 1) return R.current.assignDueSoon;
    if (left.inHours < 24) {
      return sprintf(R.current.deadlineRemainingHours, [left.inHours]);
    }
    return sprintf(R.current.deadlineRemainingDays, [left.inDays]);
  }

  List<_Section> _sectionsOf(List<MoodleActionEvent> events, DateTime now) {
    final sections = <_Section>[];
    for (final group in UpcomingEventUtils.groupByDeadline(events, now)) {
      if (group.bucket != DeadlineBucket.later) {
        sections
            .add(_Section(_labelOf(group.bucket), group.events, group.bucket));
        continue;
      }
      // groupByDeadline 已經照 timesort 排好，同一個月份的一定是相連的。
      final byMonth = <String, List<MoodleActionEvent>>{};
      for (final event in group.events) {
        final due = event.dueTime;
        byMonth.putIfAbsent('${due.year}-${due.month}', () => []).add(event);
      }
      for (final month in byMonth.values) {
        sections.add(_Section(
            _monthLabelOf(month.first.dueTime, now), month, group.bucket));
      }
    }
    return sections;
  }

  /// 本月剩下的那幾天寫「9月下半」，之後的月份只寫月份；跨年補年份。
  static String _monthLabelOf(DateTime due, DateTime now) {
    final month = due.year == now.year
        ? DateFormat.MMM().format(due)
        : DateFormat.yMMM().format(due);
    return (due.year == now.year && due.month == now.month)
        ? sprintf(R.current.deadlineRestOfMonth, [month])
        : month;
  }

  static String _labelOf(DeadlineBucket bucket) => switch (bucket) {
        DeadlineBucket.overdue => R.current.deadlineOverdue,
        DeadlineBucket.today => R.current.deadlineToday,
        DeadlineBucket.thisWeek => R.current.deadlineThisWeek,
        DeadlineBucket.later => R.current.deadlineLater,
      };

  static IconData _iconFor(String? modulename) => switch (modulename) {
        'assign' => LucideIcons.clipboardList,
        'quiz' => LucideIcons.fileQuestion,
        'forum' => LucideIcons.messagesSquare,
        'lesson' || 'scorm' => LucideIcons.bookOpen,
        'choice' || 'feedback' || 'survey' => LucideIcons.vote,
        _ => LucideIcons.calendarDays,
      };
}

/// 畫面上的一組：標題、那一組的事件，以及它從哪個 bucket 來（決定顏色）。
class _Section {
  const _Section(this.label, this.events, this.bucket);

  final String label;
  final List<MoodleActionEvent> events;
  final DeadlineBucket bucket;
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => SectionEmptyState(
        icon: LucideIcons.calendar,
        message: R.current.upcomingEventsEmpty,
      );
}
