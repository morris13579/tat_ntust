import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_colors.dart';
import 'package:flutter_app/src/controller/calendar/calendar_controller.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

/*
firstDay是日曆的第一天。用戶將無法在訪問前幾天訪問。
lastDay是日曆的最後可用日期。幾天后用戶將無法訪問。
focusedDay是當前的目標日期。使用此屬性來確定當前應顯示的月份。
 */
final kNow = DateTime.now();
final kFirstDay = DateTime(kNow.year, kNow.month - 12, kNow.day);
final kLastDay = DateTime(kNow.year, kNow.month + 12, kNow.day);

class CalendarPage extends GetView<CalendarController> {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(CalendarController());
    return Obx(() {
      return Scaffold(
        appBar: mainAppbar(title: R.current.calendar, action: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            splashRadius: 18,
            iconSize: 24,
            onPressed: () async {
              await controller.addEvent(forceUpdate: true);
            },
            tooltip: R.current.update,
          ),
        ]),
        body: Column(
          children: [
            TableCalendar<String>(
              locale: (LanguageUtils.getLangIndex() == LangEnum.zh)
                  ? "zh_CN"
                  : "en_US",
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
              },
              daysOfWeekHeight: 24,
              firstDay: kFirstDay,
              lastDay: kLastDay,
              focusedDay: controller.focusedDay.value,
              selectedDayPredicate: (day) =>
                  isSameDay(controller.selectedDay.value, day),
              rangeStartDay: controller.rangeStart.value,
              rangeEndDay: controller.rangeEnd.value,
              calendarFormat: controller.calendarFormat.value,
              rangeSelectionMode: controller.rangeSelectionMode.value,
              eventLoader: (day) => controller.events[day] ?? [],
              startingDayOfWeek: StartingDayOfWeek.monday,
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Colors.grey,
                ),
                weekendStyle: TextStyle(
                  color: Colors.deepOrange,
                ),
              ),
              calendarStyle: CalendarStyle(
                // Use `CalendarStyle` to customize the UI
                outsideDaysVisible: false,
                weekendTextStyle: const TextStyle(
                  color: Colors.deepOrange,
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(width: 1.2, color: Colors.deepOrange)),
                todayDecoration: BoxDecoration(
                  color: Colors.deepOrange[200],
                  shape: BoxShape.circle,
                ),
              ),
              onDaySelected: controller.onDaySelected,
              onFormatChanged: controller.onFormatChanged,
              onPageChanged: controller.onPageChanged,
            ),
            const SizedBox(height: 8.0),
            Expanded(child: _buildEventList()),
          ],
        ),
      );
    });
  }

  Widget _buildEventList() {
    return ListView(
      children: controller.selectedEvents
          .map((event) => Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      width: 0.8, color: Get.iconColor ?? Colors.grey),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                margin:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                    title: Text(
                      event,
                      style: const TextStyle(height: 1.2),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    onTap: () {}),
              ))
          .toList(),
    );
  }
}
