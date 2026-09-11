import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_table_share_codec.dart';

/// 把掃到的分享碼還原成一份可以畫的課表。純函式，不碰網路。
///
/// **離線就畫得出來**是這個載體設計的重點：QR 裡有課號與上課時間，所以格子的
/// 位置立刻就對；課名與教室要有網路才補得回來（[enrich]）。找共同空堂需要的
/// 只有時間，所以沒補到名字也還是有用。
class SharedTableBuilder {
  SharedTableBuilder._();

  /// 只用 QR 裡的東西組出課表。課名先放課號——留白會讓格子看起來是壞的。
  static CourseTableJson build(SharedTablePayload payload) {
    final table = CourseTableJson(
      courseSemester:
          SemesterJson(year: payload.year, semester: payload.semester),
      studentId: payload.studentId,
    );
    for (final course in payload.courses) {
      final info = CourseInfoJson()
        ..main = CourseMainInfoJson(
          course: CourseMainJson(
            id: course.id,
            name: course.id,
            time: {for (final day in Day.values) day: ''},
          ),
        );
      for (final slot in course.slots) {
        table.courseInfoMap[slot.day]![slot.section] = info;
      }
      // 順手把 time 也填回去，之後要再編碼一次（例如轉存成自己的收藏）時
      // 才拿得到同一份資料。
      _fillTime(info.main.course, course.slots);
    }
    return table;
  }

  static void _fillTime(CourseMainJson course, List<SharedSlot> slots) {
    final byDay = <Day, List<String>>{};
    for (final slot in slots) {
      byDay
          .putIfAbsent(slot.day, () => [])
          .add(slot.section.name.split('_')[1]);
    }
    for (final entry in byDay.entries) {
      course.time[entry.key] = entry.value.join(' ');
    }
  }

  /// 用查回來的課程資料把課名、教室、老師、學分補上。
  ///
  /// 查不到的課保持原樣（課名還是課號）——對方的課表可能有這學期查不到的課，
  /// 那不該讓整份課表變成空白。
  static void enrich(CourseTableJson table, List<CourseMainInfoJson> courses) {
    final byId = {for (final course in courses) course.course.id: course};
    for (final day in Day.values) {
      final row = table.courseInfoMap[day];
      if (row == null) continue;
      for (final entry in row.entries) {
        final found = byId[entry.value.main.course.id];
        if (found == null) continue;
        final target = entry.value.main;
        target.course.name = found.course.name;
        target.course.credits = found.course.credits;
        target.course.category = found.course.category;
        target.course.note = found.course.note;
        target.classroom = found.classroom;
        target.teacher = found.teacher;
      }
    }
  }
}
