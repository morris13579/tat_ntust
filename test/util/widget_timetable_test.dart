import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/widget_timetable.dart';
import 'package:flutter_test/flutter_test.dart';

/// 小工具顯示哪一張課表、連堂怎麼併。這裡錯了，桌面上會是別人的課表，或一門三節的課被拆成三格。
CourseMainInfoJson course(String id, String name, Map<Day, String> time) {
  final full = {for (final d in Day.values) d: ''}..addAll(time);
  return CourseMainInfoJson(
    course: CourseMainJson(id: id, name: name, credits: '3', time: full),
  );
}

CourseTableJson table(List<CourseMainInfoJson> courses,
    {String studentId = 'B11230223', String semester = '115-1'}) {
  final parts = semester.split('-');
  final t = CourseTableJson(
    courseSemester: SemesterJson(year: parts[0], semester: parts[1]),
    studentId: studentId,
  );
  for (final c in courses) {
    expect(t.addCourseDetailByCourseInfo(c), isTrue);
  }
  return t;
}

void main() {
  group('挑課表', () {
    List<CourseMainInfoJson> algorithms() =>
        [course('CS1', '演算法', {Day.monday: '2'})];

    test('自己的課表，學期新的在前，別人的不算', () {
      final tables = WidgetTimetable.mine([
        table(algorithms(), semester: '114-2'),
        table(algorithms(), semester: '115-1'),
        table(algorithms(), studentId: 'B10000000', semester: '116-1'),
        table(algorithms(), semester: '114-1'),
      ], 'B11230223');

      expect(
          tables.map(
              (t) => '${t.courseSemester.year}-${t.courseSemester.semester}'),
          ['115-1', '114-2', '114-1']);
    });

    test('沒有帳號或只有空課表時是空的', () {
      expect(WidgetTimetable.mine([table(algorithms())], ''), isEmpty);
      expect(WidgetTimetable.mine([table([])], 'B11230223'), isEmpty);
    });
  });

  group('連堂', () {
    test('同一天節次相連的同一門課併成一段', () {
      final spans = WidgetTimetable.lessons(
          table([course('CS1', '演算法', {Day.monday: '234'})]));

      expect(spans.map((s) => (s.day, s.firstSection, s.lastSection)),
          [(Day.monday.index, 1, 3)]);
    });

    test('隔著中午的空堂是兩段，相鄰的不同課也分開', () {
      final spans = WidgetTimetable.lessons(table([
        course('CS1', '演算法', {Day.tuesday: '45'}),
        course('CS2', '計算機組織', {Day.friday: '2'}),
        course('CS3', '資料庫系統', {Day.friday: '3'}),
      ]));

      expect(
          spans.map((s) => (s.day, s.firstSection, s.lastSection, s.courseId)),
          [
            (Day.tuesday.index, 3, 3, 'CS1'),
            (Day.tuesday.index, 5, 5, 'CS1'),
            (Day.friday.index, 1, 1, 'CS2'),
            (Day.friday.index, 2, 2, 'CS3'),
          ]);
    });

    test('顏色和課表格子一樣依課號的順序', () {
      final spans = WidgetTimetable.lessons(table([
        course('CS1', '演算法', {Day.monday: '2'}),
        course('CS2', '計算機組織', {Day.monday: '3'}),
      ]));

      expect(spans.map((s) => (s.courseId, s.order)), [('CS1', 0), ('CS2', 1)]);
    });
  });
}
