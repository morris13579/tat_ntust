import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_table_control.dart';

/// 小工具上的一堂課：同一天、節次相連的同一門課併成一段。
class WidgetLessonSpan {
  const WidgetLessonSpan({
    required this.day,
    required this.firstSection,
    required this.lastSection,
    required this.courseId,
    required this.name,
    required this.classroom,
    required this.order,
  });

  /// [Day] 的索引。
  final int day;

  /// [SectionNumber] 的索引。
  final int firstSection;
  final int lastSection;
  final String courseId;
  final String name;
  final String classroom;

  /// 課號在課表裡的順序，和課表格子挑顏色的依據相同。
  final int order;

  WidgetLessonSpan extendTo(int section) => WidgetLessonSpan(
        day: day,
        firstSection: firstSection,
        lastSection: section,
        courseId: courseId,
        name: name,
        classroom: classroom,
        order: order,
      );
}

/// 桌面與鎖定畫面的小工具顯示什麼。小工具裡跑不了核心，由原生端先要一份寫好給它。
class WidgetTimetable {
  WidgetTimetable._();

  /// 自己的課表，學期新的在前，同一學期只留一張。畫面上正在看的是別人的課表，不影響小工具。
  static List<CourseTableJson> mine(
      Iterable<CourseTableJson> tables, String account) {
    if (account.isEmpty) return [];
    final seen = <String>{};
    final result = [
      for (final table in tables)
        if (table.studentId == account &&
            table.getCourseIdList().isNotEmpty &&
            seen.add(_key(table.courseSemester)))
          table,
    ];
    result.sort(
        (a, b) => _rank(b.courseSemester).compareTo(_rank(a.courseSemester)));
    return result;
  }

  /// 依星期、節次排好的課。連堂併成一段；中間隔著一節空堂（例如中午）就是兩段。
  static List<WidgetLessonSpan> lessons(CourseTableJson table) {
    final control = CourseTableControl()..set(table);
    final ids = table.getCourseIdList();
    final spans = <WidgetLessonSpan>[];
    for (final day in control.getDayIntList) {
      if (day == Day.unKnown.index) continue;
      for (final section in control.getSectionIntList) {
        final info = control.getCourseInfo(day, section);
        if (info == null || info.isEmpty) continue;
        final id = info.main.course.id;
        final last = spans.isEmpty ? null : spans.last;
        if (last != null &&
            last.day == day &&
            last.courseId == id &&
            last.lastSection == section - 1) {
          spans[spans.length - 1] = last.extendTo(section);
          continue;
        }
        spans.add(WidgetLessonSpan(
          day: day,
          firstSection: section,
          lastSection: section,
          courseId: id,
          name: info.main.course.name,
          classroom: info.main.getClassroomName(),
          order: ids.indexOf(id),
        ));
      }
    }
    return spans;
  }

  static String _key(SemesterJson semester) =>
      '${semester.year}-${semester.semester}';

  static int _rank(SemesterJson semester) =>
      (int.tryParse(semester.year) ?? 0) * 10 +
      (int.tryParse(semester.semester) ?? 0);
}
