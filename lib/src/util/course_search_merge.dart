import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/util/course_table_conflict.dart';

/// 搜尋結果裡同一個課號的幾筆併成一門。
///
/// querycourse 同一門課開在不同時段或教室時回好幾筆（例如建築設計(三) 週二 8–9 在 RB-809A、
/// 週四 3–10 在 RB-708）。一筆一列的話，衝堂只看得到那一筆的節次，而加課照課號拿到的是第一筆：
/// 畫面上沒衝堂的那一列，加進去的卻是會撞的另一筆，而且另一筆的節次永遠不會進課表。
///
/// 只給搜尋用。課表是照課號逐筆放格子（每一格記著那一筆自己的教室），不要拿這個去併。
class CourseSearchMerge {
  CourseSearchMerge._();

  /// 照第一次出現的順序；沒有課號的不併。
  static List<CourseMainInfoJson> byCourseId(
      List<CourseMainInfoJson> records) {
    final groups = <Object, List<CourseMainInfoJson>>{};
    for (final (index, record) in records.indexed) {
      final id = record.course.id;
      groups.putIfAbsent(id.isEmpty ? index : id, () => []).add(record);
    }
    return [
      for (final group in groups.values)
        group.length == 1 ? group.single : _merge(group),
    ];
  }

  static CourseMainInfoJson _merge(List<CourseMainInfoJson> group) {
    final first = group.first.course;
    return CourseMainInfoJson(
      course: CourseMainJson(
        name: first.name,
        id: first.id,
        href: first.href,
        note: first.note,
        credits: first.credits,
        hours: first.hours,
        category: first.category,
        select: first.select,
        time: {
          for (final day in CourseTableConflict.days)
            day: group
                .map((record) => record.course.time[day] ?? '')
                .where((time) => time.trim().isNotEmpty)
                .join(' '),
        },
      ),
      teacher: _distinct(group.expand((record) => record.teacher),
          (TeacherJson teacher) => teacher.name),
      classroom: _distinct(group.expand((record) => record.classroom),
          (ClassroomJson classroom) => classroom.name),
      openClass: _distinct(group.expand((record) => record.openClass),
          (ClassJson openClass) => openClass.name),
    );
  }

  static List<T> _distinct<T>(Iterable<T> items, String Function(T) keyOf) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(keyOf(item))) item
    ];
  }
}
