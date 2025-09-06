import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/task/ntust/ntust_calendar_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
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

  @override
  Future<void> onInit() async {
    super.onInit();
    await addEvent();
  }

  Future<void> addEvent({bool forceUpdate = false}) async {
    events.clear();
    TaskFlow taskFlow = TaskFlow();
    NTUSTCalendarTask task = NTUSTCalendarTask(forceUpdate: forceUpdate);
    taskFlow.addTask(task);
    if (await taskFlow.start(checkNetwork: false)) {
      String savePath = task.result;
      final icsLines = await File(savePath).readAsLines();
      final iCalendar = ICalendar.fromLines(icsLines);
      for (var i in iCalendar.data) {
        if(!i.containsKey("dtstart") || !i.containsKey("summary")) {
          continue;
        }

        IcsDateTime timeStart = i["dtstart"];
        DateTime dt = DateTime.parse(timeStart.dt);
        var time = DateTime.utc(dt.year, dt.month, dt.day);
        String event = i["summary"];
        for (var i in event.split("  ")) {
          i = i.replaceAll(" ", "");
          if (i != "") {
            final isInt = int.tryParse(i[0]) != null;
            if(isInt) {
              i = i.substring(2, i.length);
            }

            if (events.containsKey(time)) {
              events[time]!.add(i);
            } else {
              events[time] = [i];
            }
          }
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
        break;
      }
    }
  }
}