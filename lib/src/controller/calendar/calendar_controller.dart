import 'package:flutter_app/debug/log/log.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_app/src/repository/calendar_repository.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:get/get.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarController extends GetxController {
  RxList<String> selectedEvents = <String>[].obs;
  RxMap<DateTime, List<String>> events = <DateTime, List<String>>{}.obs;
  Rx<CalendarFormat> calendarFormat = Rx(CalendarFormat.month);
  Rx<RangeSelectionMode> rangeSelectionMode = Rx(RangeSelectionMode.toggledOff);
  Rx<DateTime> focusedDay = DateTime.now().obs;
  Rx<DateTime> selectedDay = DateTime.now().obs;
  Rx<DateTime?> rangeStart = Rx(null);
  Rx<DateTime?> rangeEnd = Rx(null);

  final upcomingEvents = Rxn<Result<List<MoodleActionEvent>>>();

  @override
  Future<void> onInit() async {
    super.onInit();
    // 與 .ics 並行，Moodle 慢或失敗都不該擋住行事曆本體；進頁時是背景預載。
    unawaited(loadUpcomingEvents(background: true));
    await addEvent();
  }

  Future<void> loadUpcomingEvents({bool background = false}) async {
    upcomingEvents.value = null;
    upcomingEvents.value = await MoodleRepository.instance
        .getUpcomingEvents(background: background);
  }

  /// 點一筆待辦要開的網址，已換成免登入網址；換不到就原網址。
  Future<String> urlToOpen(MoodleActionEvent event) async {
    final target = event.openUrl;
    try {
      return await MoodleWebApiConnector.autologinUrl(target);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return target;
    }
  }

  /// 依序跑（.ics 會開進度框，待辦可能開登入頁），兩個 UI 才不會疊在一起。
  Future<void> refreshAll() async {
    await addEvent(forceUpdate: true);
    await loadUpcomingEvents();
  }

  @override
  void onClose() {
    upcomingEvents.close();
    super.onClose();
  }

  Future<void> addEvent({bool forceUpdate = false}) async {
    events.clear();
    // 檔案已經在磁碟上就直接回 Ok，不需要網路。
    final result = await CalendarRepository.instance
        .getCalendarFile(forceUpdate: forceUpdate);
    final savePath = result.dataOrNull;
    if (savePath != null) {
      final icsLines = await File(savePath).readAsLines();
      final iCalendar = ICalendar.fromLines(icsLines);
      for (var i in iCalendar.data) {
        if (!i.containsKey("dtstart") || !i.containsKey("summary")) {
          continue;
        }

        // 單筆解析失敗只跳過該筆，否則例外會讓畫面停在半份行事曆。
        try {
          IcsDateTime timeStart = i["dtstart"];
          DateTime dt = DateTime.parse(timeStart.dt);
          var time = DateTime.utc(dt.year, dt.month, dt.day);
          String event = i["summary"];
          for (var raw in event.split("  ")) {
            // 剝掉開頭的編號前綴。不可換成固定長度切割：編號可能是兩位數。
            final item = raw
                .replaceAll(" ", "")
                .replaceFirst(RegExp(r'^\d+[.、,:]?'), '');
            if (item.isEmpty) continue;
            events.putIfAbsent(time, () => []).add(item);
          }
        } catch (e, stack) {
          Log.eWithStack(e.toString(), stack);
          continue;
        }
      }
      var today = DateTime.now().toUtc();
      today = today.add(const Duration(hours: 8)); //to TW time

      selectedDay.value = today;
      selectedEvents.value = events[today] ?? [];

      _selectEvent();
    }
  }

  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(this.focusedDay.value, focusedDay)) {
      this.selectedDay.value = selectedDay;
      this.focusedDay.value = focusedDay;
      rangeStart.value = null;
      rangeEnd.value = null;
      rangeSelectionMode.value = RangeSelectionMode.toggledOff;
      selectedEvents.value = events[focusedDay] ?? [];
      HapticFeedback.lightImpact();
    }
  }

  void onFormatChanged(CalendarFormat format) {
    if (calendarFormat.value != format) {
      calendarFormat.value = format;
    }
  }

  void onPageChanged(DateTime focusedDay) {
    this.focusedDay.value = focusedDay;
    _getEvent(focusedDay);
  }

  Future<void> _getEvent(DateTime time) async {
    selectedDay.value = time;
    _selectEvent();
  }

  void _selectEvent() {
    for (DateTime time in events.keys) {
      if (selectedDay.value.year == time.year &&
          selectedDay.value.month == time.month &&
          selectedDay.value.day == time.day) {
        selectedEvents.value = events[time] ?? [];
        return;
      }
    }
    // 找不到就要清空，否則換月後清單會繼續顯示上一天的事件。
    selectedEvents.clear();
  }
}
