import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/task/ntust/ntust_calendar_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:table_calendar/table_calendar.dart';

/*
firstDay是日曆的第一天。用戶將無法在訪問前幾天訪問。
lastDay是日曆的最後可用日期。幾天后用戶將無法訪問。
focusedDay是當前的目標日期。使用此屬性來確定當前應顯示的月份。
 */
final kNow = DateTime.now();
final kFirstDay = DateTime(kNow.year, kNow.month - 12, kNow.day);
final kLastDay = DateTime(kNow.year, kNow.month + 12, kNow.day);

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late List _selectedEvents;
  Map<DateTime, List<String>> _events = Map();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOff;
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = [];
    _addEvent();
  }

  void _addEvent({bool forceUpdate: false}) async {
    _events = {};
    TaskFlow taskFlow = TaskFlow();
    NTUSTCalendarTask task = NTUSTCalendarTask(forceUpdate: forceUpdate);
    taskFlow.addTask(task);
    if (await taskFlow.start(checkNetwork: false)) {
      String savePath = task.result;
      final icsLines = await File(savePath).readAsLines();
      final iCalendar = ICalendar.fromLines(icsLines);
      for (var i in iCalendar.data) {
        IcsDateTime timeStart = i["dtstart"];
        DateTime dt = DateTime.parse(timeStart.dt);
        var time = DateTime.utc(dt.year, dt.month, dt.day);
        String event = i["summary"];
        for (var i in event.split("  ")) {
          i = i.replaceAll(" ", "");
          if (i != "") {
            try {
              int.parse(i[0]);
              i = i.substring(2, i.length);
            } catch (e) {}
            if (_events.containsKey(time)) {
              _events[time]!.add(i);
            } else {
              _events[time] = [i];
            }
          }
        }
      }
      var _today = DateTime.now().toUtc();
      _today = _today.add(Duration(hours: 8)); //to TW time
      setState(() {
        _selectedDay = _today;
      });
      _selectEvent();
    }
  }

  void _selectEvent() {
    for (DateTime time in _events.keys) {
      if (_selectedDay.year == time.year &&
          _selectedDay.month == time.month &&
          _selectedDay.day == time.day) {
        setState(() {
          _selectedEvents = _events[time] ?? [];
        });
        break;
      }
    }
  }

  Future<void> _getEvent(DateTime time) async {
    setState(() {
      _selectedDay = time;
    });
    _selectEvent();
  }

  List<String> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_focusedDay, focusedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _rangeStart = null; // Important to clean those
        _rangeEnd = null;
        _rangeSelectionMode = RangeSelectionMode.toggledOff;
        _selectedEvents = _getEventsForDay(focusedDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(R.current.calendar),
        actions: [
          IconButton(
            onPressed: () {
              _addEvent(forceUpdate: true);
            },
            icon: Icon(Icons.update_outlined),
            tooltip: R.current.update,
          )
        ],
      ),
      body: Column(
        children: [
          TableCalendar<String>(
            locale: (LanguageUtils.getLangIndex() == LangEnum.zh)
                ? "zh_CN"
                : "en_US",
            availableCalendarFormats: {
              CalendarFormat.month: 'Month',
            },
            daysOfWeekHeight: 24,
            firstDay: kFirstDay,
            lastDay: kLastDay,
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            rangeStartDay: _rangeStart,
            rangeEndDay: _rangeEnd,
            calendarFormat: _calendarFormat,
            rangeSelectionMode: _rangeSelectionMode,
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: Color(0xFF4F4F4F),
              ),
              weekendStyle: TextStyle(
                color: Colors.deepOrange,
              ),
            ),
            calendarStyle: CalendarStyle(
              // Use `CalendarStyle` to customize the UI
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(
                color: Colors.deepOrange,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.brown[700],
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.deepOrange[300],
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.deepOrange[200],
                shape: BoxShape.circle,
              ),
            ),
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _getEvent(_focusedDay);
            },
          ),
          const SizedBox(height: 8.0),
          Expanded(child: _buildEventList()),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    return ListView(
      children: _selectedEvents
          .map((event) => Container(
                decoration: BoxDecoration(
                  border: Border.all(width: 0.8),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                margin:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(title: Text(event), onTap: () {}),
              ))
          .toList(),
    );
  }
}
