import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';

/// 一格衝堂：同一個 (星期, 節次) 上有兩門課。
class ConflictCell {
  const ConflictCell({
    required this.day,
    required this.section,
    required this.base,
    required this.overlay,
  });

  /// 原本課表上那一門。
  final CourseInfoJson base;

  /// 疊上去那一門（模擬課表的草稿、或別人的課表）。
  final CourseInfoJson overlay;

  final Day day;
  final SectionNumber section;
}

/// 課表的衝堂與疊圖。純函式，沒有 UI 也沒有網路。
///
/// 不能重用 `CourseTableJson.addCourseDetailByCourseInfo`：它一遇到衝堂就
/// `return false` 拒絕加入，那是「加課」語意。模擬排課要的是「先加進去，再
/// 把衝到的地方標出來」。
class CourseTableConflict {
  CourseTableConflict._();

  /// 真正排得出課的星期。
  ///
  /// **不能含 [Day.unKnown]**：沒有時間的課會被 `setCourseDetailByTime` 塞進
  /// unKnown 那一欄的連續格子裡，兩門都沒時間的課會佔到同一格，那不是衝堂。
  static const int _realDayCount = 7;

  static Iterable<Day> get days => Day.values.take(_realDayCount);

  /// 同理，`t_UnKnown` 是「沒有節次」的收納格，不算衝堂。
  static Iterable<SectionNumber> get sections =>
      SectionNumber.values.where((s) => s != SectionNumber.t_UnKnown);

  /// [base] 與 [overlay] 撞在一起的每一格。
  ///
  /// 同一門課跨兩節就會回兩格：畫面要在每一格都標紅，而「幾處衝堂」數的也是
  /// 格子數（設計稿的「3 處衝堂 · 三 3、四 6、四 7」就是三格）。
  static List<ConflictCell> findConflicts(
      CourseTableJson base, CourseTableJson overlay) {
    final cells = <ConflictCell>[];
    for (final day in days) {
      final baseDay = base.courseInfoMap[day];
      final overlayDay = overlay.courseInfoMap[day];
      if (baseDay == null || overlayDay == null) continue;
      for (final section in sections) {
        final a = baseDay[section];
        final b = overlayDay[section];
        if (a == null || b == null) continue;
        // 同一門課出現在兩邊不是衝堂，是「這門課本來就在課表上」。
        if (a.main.course.id.isNotEmpty &&
            a.main.course.id == b.main.course.id) {
          continue;
        }
        cells
            .add(ConflictCell(day: day, section: section, base: a, overlay: b));
      }
    }
    return cells;
  }

  /// 把 [course] 加進 [table] 會撞到哪幾格。加課前用這個問，不必真的加。
  static List<ConflictCell> conflictsOf(
      CourseTableJson table, CourseMainInfoJson course) {
    final cells = <ConflictCell>[];
    final probe = CourseInfoJson()..main = course;
    for (final day in days) {
      final occupied = table.courseInfoMap[day];
      if (occupied == null) continue;
      for (final section in sectionsOf(course.course.time[day])) {
        final taken = occupied[section];
        if (taken == null) continue;
        if (taken.main.course.id.isNotEmpty &&
            taken.main.course.id == course.course.id) {
          continue;
        }
        cells.add(ConflictCell(
            day: day, section: section, base: taken, overlay: probe));
      }
    }
    return cells;
  }

  /// 課表上這門課佔到的節次。
  ///
  /// `CourseMainJson.time` 的預設值是 `const {}`，查不到的星期是 null；
  /// 這裡吃 null 而不是 `!`，不然沒有時間的課會直接丟 TypeError。
  static List<SectionNumber> sectionsOf(String? time) {
    if (time == null || time.trim().isEmpty) return const [];
    final sections = <SectionNumber>[];
    for (final value in SectionNumber.values) {
      if (value == SectionNumber.t_UnKnown) continue;
      final name = value.name.split('_')[1];
      for (final token in time.split(' ')) {
        if (token.contains(name) && !sections.contains(value)) {
          sections.add(value);
        }
      }
    }
    return sections;
  }
}
