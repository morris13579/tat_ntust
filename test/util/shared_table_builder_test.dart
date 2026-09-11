import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_table_share_codec.dart';
import 'package:flutter_app/src/util/shared_table_builder.dart';
import 'package:flutter_test/flutter_test.dart';

/// 掃到的碼還原成課表。離線就要畫得出格子，課名有網路再補。
void main() {
  SharedTablePayload payloadOf(String code) =>
      CourseTableShareCodec.decode(code)!;

  test('格子位置離線就對得起來，課名先放課號', () {
    final table =
        SharedTableBuilder.build(payloadOf('TAT21151B10000000AA1000001.434'));
    expect(table.studentId, 'B10000000');
    expect(table.courseSemester.year, '115');
    expect(table.courseSemester.semester, '1');
    final cell = table.courseInfoMap[Day.thursday]![SectionNumber.t_3];
    expect(cell, isNotNull);
    expect(cell!.main.course.id, 'AA1000001');
    // 課名留白會讓格子看起來像壞掉。
    expect(cell.main.course.name, 'AA1000001');
    expect(table.courseInfoMap[Day.thursday]![SectionNumber.t_4], isNotNull);
    expect(table.courseInfoMap[Day.thursday]![SectionNumber.t_5], isNull);
  });

  test('同一門課的每一格指到同一個物件——補課名時才會一次補完', () {
    final table =
        SharedTableBuilder.build(payloadOf('TAT21151B10000000AA1000001.434'));
    expect(
      identical(table.courseInfoMap[Day.thursday]![SectionNumber.t_3],
          table.courseInfoMap[Day.thursday]![SectionNumber.t_4]),
      isTrue,
    );
  });

  test('time 也填回去，之後要重新編碼才拿得到同一份資料', () {
    final table = SharedTableBuilder.build(
        payloadOf('TAT21151B10000000AA1000001.434-AA1000002.29'));
    final again = CourseTableShareCodec.decode(
        CourseTableShareCodec.encodePayload(table))!;
    expect(again.courses.map((c) => c.id).toSet(), {'AA1000001', 'AA1000002'});
    expect(
        again.courses
            .firstWhere((c) => c.id == 'AA1000001')
            .slots
            .map((s) => s.section)
            .toList(),
        [SectionNumber.t_3, SectionNumber.t_4]);
  });

  test('沒有時間的課不會佔到格子', () {
    final table =
        SharedTableBuilder.build(payloadOf('TAT21151B10000000AA100B003'));
    for (final day in Day.values) {
      for (final section in SectionNumber.values) {
        expect(table.courseInfoMap[day]![section], isNull);
      }
    }
  });

  group('enrich', () {
    CourseMainInfoJson courseOf(String id, String name) => CourseMainInfoJson(
          course:
              CourseMainJson(id: id, name: name, credits: '3', time: const {}),
          classroom: [ClassroomJson(name: 'AA-101', href: '')],
          teacher: [TeacherJson(name: '某某某', href: '')],
        );

    test('查回來的課名、教室、老師都補得上，而且每一格都跟著換', () {
      final table =
          SharedTableBuilder.build(payloadOf('TAT21151B10000000AA1000001.434'));
      SharedTableBuilder.enrich(table, [courseOf('AA1000001', '離散數學')]);
      for (final section in [SectionNumber.t_3, SectionNumber.t_4]) {
        final cell = table.courseInfoMap[Day.thursday]![section]!;
        expect(cell.main.course.name, '離散數學');
        expect(cell.main.getClassroomName().trim(), 'AA-101');
        expect(cell.main.getTeacherName().trim(), '某某某');
      }
    });

    test('查不到的課保持原樣，不會整張表變空白', () {
      final table = SharedTableBuilder.build(
          payloadOf('TAT21151B10000000AA1000001.434-AA1000002.29'));
      SharedTableBuilder.enrich(table, [courseOf('AA1000001', '離散數學')]);
      expect(
          table.courseInfoMap[Day.thursday]![SectionNumber.t_3]!.main.course
              .name,
          '離散數學');
      // 沒查到的那一門還是課號。
      expect(
          table
              .courseInfoMap[Day.tuesday]![SectionNumber.t_9]!.main.course.name,
          'AA1000002');
    });

    test('空的查詢結果不會動到任何東西', () {
      final table =
          SharedTableBuilder.build(payloadOf('TAT21151B10000000AA1000001.434'));
      SharedTableBuilder.enrich(table, const []);
      expect(
          table.courseInfoMap[Day.thursday]![SectionNumber.t_3]!.main.course
              .name,
          'AA1000001');
    });
  });
}
