import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/controller/calendar/calendar_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/calendar/components/calendar_day_cell.dart';
import 'package:flutter_app/ui/pages/calendar/components/calendar_event_row.dart';
import 'package:flutter_app/ui/pages/calendar/components/calendar_legend.dart';
import 'package:flutter_app/ui/pages/calendar/components/section_count_label.dart';
import 'package:flutter_app/ui/pages/calendar/upcoming_events_section.dart';
import 'package:flutter_app/ui/pages/web_view/inapp_web_view_page.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

/*
kFirstDay / kLastDay 是日曆可存取範圍的上下界，超出這段的日期使用者點不到。
 */
final kNow = DateTime.now();
final kFirstDay = DateTime(kNow.year, kNow.month - 12, kNow.day);
final kLastDay = DateTime(kNow.year, kNow.month + 12, kNow.day);

class CalendarPage extends GetView<CalendarController> {
  const CalendarPage({super.key, required this.openInApp});

  /// 待辦點下去先問這一個：開得成 App 內的 Moodle 頁面就回 true，回 false 才
  /// 落回 WebView。導頁由呼叫端注入，這一頁不 import route_utils。
  final Future<bool> Function(BuildContext context, MoodleActionEvent event)
      openInApp;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 兩種圓點各自的日期集合。學校行事曆來自 .ics，作業截止來自 Moodle 待辦，
      // 兩份資料本來就分開存，這裡只是攤成「哪一天有東西」。
      final schoolDays = {
        for (final day in controller.events.keys) _dayKey(day),
      };
      final deadlineDays = {
        for (final event in controller.upcomingEvents.value?.dataOrNull ??
            const <MoodleActionEvent>[])
          _dayKey(event.dueTime),
      };
      final dayEvents = controller.selectedEvents.toList();

      return Scaffold(
        appBar: mainAppbar(title: R.current.calendar, action: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            splashRadius: 18,
            onPressed: controller.refreshAll,
            tooltip: R.current.update,
          ),
        ]),
        body: Column(
          children: [
            _buildCalendar(context, schoolDays, deadlineDays),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  ..._buildDaySection(context, dayEvents),
                  UpcomingEventsSection(
                    // 上面已經畫了學校行事曆那一段時，待辦的第一個組標題要改
                    // 用區塊之間的上距，不然兩塊的間距比組內還窄。
                    first: dayEvents.isEmpty,
                    state: controller.upcomingEvents,
                    onRetry: () => controller.loadUpcomingEvents(),
                    onOpen: (event) => _openEvent(context, event),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  /// 月曆本體。底色與 appbar 同一張白，下面收一條細線，讓它讀起來是 appbar 的
  /// 延伸而不是另一張卡。
  Widget _buildCalendar(
    BuildContext context,
    Set<DateTime> schoolDays,
    Set<DateTime> deadlineDays,
  ) {
    final scheme = context.scheme;
    final text = context.text;
    final today = DateTime.now();
    final dowStyle = text.labelMedium?.copyWith(color: scheme.onSurfaceVariant);

    return Container(
      decoration: BoxDecoration(
        color: context.tokens.card,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TableCalendar<String>(
            locale: (LanguageUtils.getLangIndex() == LangEnum.zh)
                ? "zh_CN"
                : "en_US",
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
            },
            daysOfWeekHeight: 22,
            rowHeight: 46,
            firstDay: kFirstDay,
            lastDay: kLastDay,
            focusedDay: controller.focusedDay.value,
            selectedDayPredicate: (day) =>
                isSameDay(controller.selectedDay.value, day),
            rangeStartDay: controller.rangeStart.value,
            rangeEndDay: controller.rangeEnd.value,
            calendarFormat: controller.calendarFormat.value,
            rangeSelectionMode: controller.rangeSelectionMode.value,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            onDaySelected: controller.onDaySelected,
            onFormatChanged: controller.onFormatChanged,
            onPageChanged: controller.onPageChanged,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              headerPadding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
              leftChevronPadding: const EdgeInsets.all(12),
              rightChevronPadding: const EdgeInsets.all(12),
              leftChevronMargin: EdgeInsets.zero,
              rightChevronMargin: EdgeInsets.zero,
              // 等寬數字：翻月時「2026年9月」不會因為位數不同左右跳動。
              titleTextStyle: AppTypography.tabular(text.titleMedium!)
                  .copyWith(color: scheme.onSurface),
              // 「2026年9月」。年在前面，跨年翻月時才不會突然看不懂。
              titleTextFormatter: (date, locale) =>
                  DateFormat.yMMM(locale).format(date),
              leftChevronIcon: Icon(LucideIcons.chevronLeft,
                  size: 20, color: scheme.onSurfaceVariant),
              rightChevronIcon: Icon(LucideIcons.chevronRight,
                  size: 20, color: scheme.onSurfaceVariant),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              // 週末不另外標色：一整排七個字裡兩個變色只是雜訊，真正要看的是
              // 底下的圓點。
              weekdayStyle: dowStyle ?? const TextStyle(),
              weekendStyle: dowStyle ?? const TextStyle(),
              // ccccc 是「單獨使用的最短星期」：中文剩一個「日」，英文剩
              // 一個 S，剛好是七格擠得下的寬度。
              dowTextFormatter: (date, locale) =>
                  DateFormat('ccccc', locale).format(date),
            ),
            calendarStyle: const CalendarStyle(outsideDaysVisible: false),
            calendarBuilders: CalendarBuilders<String>(
              // 一個 builder 畫完所有狀態：今天、選取、一般、超出範圍的日期
              // 各自的樣子都在 CalendarDayCell 裡，不會四處散落。
              prioritizedBuilder: (context, day, focusedDay) {
                final key = _dayKey(day);
                return CalendarDayCell(
                  day: day,
                  isToday: isSameDay(day, today),
                  isSelected: isSameDay(controller.selectedDay.value, day),
                  hasSchoolEvent: schoolDays.contains(key),
                  hasDeadline: deadlineDays.contains(key),
                  enabled: !day.isBefore(kFirstDay) && !day.isAfter(kLastDay),
                );
              },
            ),
          ),
          const CalendarLegend(),
        ],
      ),
    );
  }

  /// 選到的那一天：學校行事曆上寫了什麼。Moodle 的截止事項在下面的「待辦」，
  /// 不在這裡重複一次。
  List<Widget> _buildDaySection(BuildContext context, List<String> events) {
    if (events.isEmpty) return const [];
    final selected = controller.selectedDay.value;
    final title = DateFormat.MMMd().format(selected);
    return [
      SectionHeader(
        title: isSameDay(selected, DateTime.now())
            ? '$title · ${R.current.deadlineToday}'
            : title,
        trailing: SectionCountLabel(events.length),
        first: true,
      ),
      for (var i = 0; i < events.length; i++) ...[
        if (i > 0) const SizedBox(height: 2),
        CalendarEventRow(
          icon: LucideIcons.building2,
          iconColor: context.scheme.primary,
          title: events[i],
          subtitle: R.current.calendarSourceSchool,
          index: i,
          length: events.length,
        ),
      ],
    ];
  }

  /// 圓點查表用的鍵。.ics 存的是 UTC 的那一天，待辦是本地時間，統一收斂成
  /// 同一種鍵才對得起來。
  static DateTime _dayKey(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day);

  /// 開一筆待辦。App 內開得成就到此為止；開不成才走 WebView，那一段的免登入
  /// 橋接、cookie 與 SSO 退路都維持原樣。
  /// 不能 import route_utils，見 docs/ARCHITECTURE.md「UI 慣例」。
  Future<void> _openEvent(BuildContext context, MoodleActionEvent event) async {
    if (await openInApp(context, event)) return;
    final raw = event.openUrl;
    final url = await controller.urlToOpen(event);
    await Get.to(
      () => InAppWebViewPage(
        title: event.title,
        url: WebUri(url),
        // 換成 autologin 網址時把原網址一起帶著，鑰匙被拒時才有地方退。
        fallbackUrl: url == raw ? null : WebUri(raw),
        openWithExternalWebView: true,
        loadDone: (_) {},
      ),
    );
  }
}
