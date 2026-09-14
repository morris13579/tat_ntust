import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/src/controller/course_table/course_model.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/src/util/widget_timetable.dart';

/// 原生版的桌面與鎖定畫面小工具。extension 裡跑不了核心，App 回到背景前向這裡要一份寫進 App Group。
class WidgetBridge implements TatWidgetApi {
  WidgetBridge([CourseModel? model]) : _model = model ?? CourseModel();

  static void install() => TatWidgetApi.setUp(WidgetBridge());

  final CourseModel _model;

  @override
  List<WidgetTable> timetables() {
    if (!AuthSession.instance.isSignedIn) return [];
    return [
      for (final table in WidgetTimetable.mine(
          _model.getCacheCourseTableList(), Model.instance.getAccount()))
        _table(table),
    ];
  }

  static WidgetTable _table(CourseTableJson table) {
    final control = CourseTableControl()..set(table);
    return WidgetTable(
      semester:
          '${table.courseSemester.year}-${table.courseSemester.semester}',
      courseCount: table.getCourseIdList().length,
      credits: table.getTotalCredit(),
      days: [
        for (final day in control.getDayIntList)
          if (day != Day.unKnown.index)
            WidgetTableDay(weekday: day + 1, label: control.getDayString(day)),
      ],
      sections: [
        for (final section in control.getSectionIntList)
          WidgetTableSection(
            index: section,
            label: control.getSectionString(section),
            start: _start(section),
            end: _end(section),
          ),
      ],
      lessons: [
        for (final span in WidgetTimetable.lessons(table))
          WidgetTableLesson(
            weekday: span.day + 1,
            firstSection: span.firstSection,
            lastSection: span.lastSection,
            start: _start(span.firstSection),
            end: _end(span.lastSection),
            name: span.name,
            classroom: span.classroom.isEmpty ? null : span.classroom,
            order: span.order,
          ),
      ],
    );
  }

  static int _start(int section) =>
      sectionTimes[section].startHour * 60 + sectionTimes[section].startMinute;

  static int _end(int section) =>
      sectionTimes[section].endHour * 60 + sectionTimes[section].endMinute;
}
