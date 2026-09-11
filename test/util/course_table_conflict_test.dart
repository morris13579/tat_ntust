import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_table_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

/// 衝堂判定。模擬排課整個功能都靠這一份，錯了會讓使用者以為排得進去。
void main() {
  CourseMainInfoJson courseOf(String id, Map<Day, String> time) {
    // addCourseDetailByCourseInfo 對七天都做 `time[day]!`，少一天就 TypeError。
    final full = {for (final day in Day.values) day: time[day] ?? ''};
    return CourseMainInfoJson(
      course: CourseMainJson(id: id, name: id, time: full),
    );
  }

  CourseTableJson tableOf(List<CourseMainInfoJson> courses) {
    final table = CourseTableJson(
      courseSemester: SemesterJson(year: '115', semester: '1'),
      studentId: 'B11000001',
    );
    for (final course in courses) {
      table.addCourseDetailByCourseInfo(course);
    }
    return table;
  }

  group('conflictsOf', () {
    test('同一天同一節就是衝堂，跨幾節就回幾格', () {
      final table = tableOf([
        courseOf('CS3003302', {Day.thursday: '3 4'})
      ]);
      final cells = CourseTableConflict.conflictsOf(
          table, courseOf('AC5012701', {Day.thursday: '3 4'}));
      expect(cells, hasLength(2));
      expect(cells.map((c) => c.section).toList(),
          [SectionNumber.t_3, SectionNumber.t_4]);
      expect(cells.every((c) => c.day == Day.thursday), isTrue);
      expect(cells.first.base.main.course.id, 'CS3003302');
      expect(cells.first.overlay.main.course.id, 'AC5012701');
    });

    test('只有部分節次重疊時，只回重疊的那幾格', () {
      final table = tableOf([
        courseOf('CS3003302', {Day.thursday: '3 4'})
      ]);
      final cells = CourseTableConflict.conflictsOf(
          table, courseOf('AC5012701', {Day.thursday: '4 5'}));
      expect(cells.map((c) => c.section).toList(), [SectionNumber.t_4]);
    });

    test('不同天不算衝堂', () {
      final table = tableOf([
        courseOf('CS3003302', {Day.thursday: '3 4'})
      ]);
      expect(
          CourseTableConflict.conflictsOf(
              table, courseOf('AC5012701', {Day.wednesday: '3 4'})),
          isEmpty);
    });

    test('同一門課不跟自己衝堂', () {
      final table = tableOf([
        courseOf('CS3003302', {Day.thursday: '3 4'})
      ]);
      expect(
          CourseTableConflict.conflictsOf(
              table, courseOf('CS3003302', {Day.thursday: '3 4'})),
          isEmpty);
    });

    test('沒有時間的課永遠排得進去', () {
      // 沒有時間的課會被塞進 unKnown 那一欄的連續格子，兩門都沒時間的課會佔到
      // 同一格——那是收納，不是衝堂。
      final table = tableOf([
        courseOf('CS490B001', const {}),
        courseOf('CS3003302', {Day.thursday: '3 4'}),
      ]);
      expect(
          CourseTableConflict.conflictsOf(
              table, courseOf('TCG159301', const {})),
          isEmpty);
    });

    test('中午的 N 節與 A-D 節照樣判得出來', () {
      final table = tableOf([
        courseOf('CS3003302', {Day.monday: 'N'})
      ]);
      expect(
          CourseTableConflict.conflictsOf(
              table, courseOf('AC5012701', {Day.monday: 'N'})).single.section,
          SectionNumber.t_N);

      final late = tableOf([
        courseOf('CS3003302', {Day.friday: 'A B'})
      ]);
      expect(
          CourseTableConflict.conflictsOf(
              late, courseOf('AC5012701', {Day.friday: 'B C'})),
          hasLength(1));
    });

    test('空課表加什麼都不衝', () {
      expect(
          CourseTableConflict.conflictsOf(
              tableOf([]), courseOf('CS3003302', {Day.thursday: '3 4'})),
          isEmpty);
    });
  });

  group('findConflicts', () {
    test('兩份課表疊起來，每一格撞到都回一筆', () {
      final mine = tableOf([
        courseOf('CS3003302', {Day.thursday: '3 4'}),
        courseOf('CS3039701', {Day.wednesday: '6 7'}),
      ]);
      final draft = tableOf([
        courseOf('AC5012701', {Day.thursday: '3'}),
        courseOf('AC5313701', {Day.friday: '1'}),
      ]);
      final cells = CourseTableConflict.findConflicts(mine, draft);
      expect(cells, hasLength(1));
      expect(cells.single.day, Day.thursday);
      expect(cells.single.section, SectionNumber.t_3);
    });

    test('同一門課同時在兩邊不算衝堂', () {
      final course = courseOf('CS3003302', {Day.thursday: '3 4'});
      expect(
          CourseTableConflict.findConflicts(
              tableOf([course]), tableOf([course])),
          isEmpty);
    });

    test('兩份都沒時間的課不會互撞', () {
      expect(
          CourseTableConflict.findConflicts(
              tableOf([courseOf('CS490B001', const {})]),
              tableOf([courseOf('TCG159301', const {})])),
          isEmpty);
    });
  });

  group('sectionsOf', () {
    test('null 與空字串都是沒有節次，不會丟例外', () {
      expect(CourseTableConflict.sectionsOf(null), isEmpty);
      expect(CourseTableConflict.sectionsOf(''), isEmpty);
      expect(CourseTableConflict.sectionsOf('   '), isEmpty);
    });

    test('照節次表的順序回傳，不是輸入順序', () {
      expect(CourseTableConflict.sectionsOf('4 3'),
          [SectionNumber.t_3, SectionNumber.t_4]);
      // t_N 夾在 t_4 與 t_5 之間，那是中午。
      expect(CourseTableConflict.sectionsOf('5 N 4'),
          [SectionNumber.t_4, SectionNumber.t_N, SectionNumber.t_5]);
    });

    test('同一節寫兩次只算一次', () {
      expect(CourseTableConflict.sectionsOf('3 3'), [SectionNumber.t_3]);
    });
  });

  group('走訪範圍', () {
    test('days 不含 unKnown，sections 不含 t_UnKnown', () {
      expect(CourseTableConflict.days, isNot(contains(Day.unKnown)));
      expect(CourseTableConflict.days, hasLength(7));
      expect(CourseTableConflict.sections,
          isNot(contains(SectionNumber.t_UnKnown)));
    });
  });
}
