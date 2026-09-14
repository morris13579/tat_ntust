import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_search_merge.dart';
import 'package:flutter_app/src/util/course_table_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

/// 搜尋結果裡同一個課號的幾筆要併成一門，衝堂與加課才看得到整門課。
void main() {
  test('真實回應裡建築設計(三)分成兩筆：併成一門，節次、教室都收齊，順序照第一次出現', () {
    final raw = jsonDecode(File('test/fixtures/querycourse/courses_1151_sample.json')
        .readAsStringSync()) as List<dynamic>;
    final records = CourseConnector.parseSearchResult(raw);

    final merged = CourseSearchMerge.byCourseId(records);

    expect(merged.length, records.length - 1);
    expect(merged.map((c) => c.course.id).toList(),
        records.map((c) => c.course.id).toSet().toList());
    final design = merged.singleWhere((c) => c.course.id == 'AD2001301');
    final parts = records.where((c) => c.course.id == 'AD2001301').toList();
    expect(parts, hasLength(2));
    for (final day in CourseTableConflict.days) {
      expect(
          CourseTableConflict.sectionsOf(design.course.time[day]).toSet(),
          {
            for (final part in parts)
              ...CourseTableConflict.sectionsOf(part.course.time[day]),
          },
          reason: '$day');
    }
    expect(CourseTableConflict.sectionsOf(design.course.time[Day.thursday]),
        hasLength(8));
    expect(design.getClassroomName(), 'RB-809A RB-708');
  });

  test('沒有課號的不併', () {
    final records = [
      CourseMainInfoJson(course: CourseMainJson(name: '甲', time: {Day.monday: '1'})),
      CourseMainInfoJson(course: CourseMainJson(name: '乙', time: {Day.monday: '2'})),
    ];

    expect(CourseSearchMerge.byCourseId(records).map((c) => c.course.name),
        ['甲', '乙']);
  });

  test('老師重複的只留一位', () {
    final records = [
      CourseMainInfoJson(
          course: CourseMainJson(id: 'X1', time: {Day.monday: '1'}),
          teacher: [TeacherJson(name: '王')]),
      CourseMainInfoJson(
          course: CourseMainJson(id: 'X1', time: {Day.friday: '2'}),
          teacher: [TeacherJson(name: '王')]),
    ];

    expect(CourseSearchMerge.byCourseId(records).single.getTeacherName(), '王');
  });
}
