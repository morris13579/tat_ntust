import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/util/course_table_conflict.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:sprintf/sprintf.dart';

/// 模擬排課的草稿怎麼改、怎麼摘要。Flutter 的模擬排課頁與原生版共用這一份。
///
/// 草稿是**另一份** [CourseTableJson]，不會寫回實際課表。
class SimulationDraft {
  SimulationDraft._();

  /// `SemesterJson.toString()` 是多行的除錯字串，既有的草稿就是拿它組成 id；
  /// 換一種寫法，使用者已經排好的草稿就再也找不到。
  static String idOf(String studentId, SemesterJson semester) =>
      'draft-$studentId-$semester';

  static ExtraTable create(String studentId, SemesterJson semester) =>
      ExtraTable(
        id: idOf(studentId, semester),
        label: sprintf(R.current.simulationDraftLabel,
            ['${semester.year}-${semester.semester}']),
        table: CourseTableJson(courseSemester: semester, studentId: studentId),
        savedAt: DateTime.now(),
      );

  /// 只有同一學期的實際課表才能當底圖；沒有下載過那一學期就是從空白課表排。
  static CourseTableJson? baseOf(
      ExtraTable draft, List<CourseTableJson> tables) {
    for (final table in tables) {
      if (table.studentId == draft.table.studentId &&
          table.courseSemester == draft.table.courseSemester) {
        return table;
      }
    }
    return null;
  }

  static Future<void> save(ExtraTable draft, [ExtraTableStore? store]) {
    draft.savedAt = DateTime.now();
    return (store ?? ExtraTableStore.instance).upsertDraft(draft);
  }

  static bool contains(CourseTableJson draft, String courseId) =>
      draft.getCourseIdList().contains(courseId);

  static bool isEmpty(CourseTableJson draft) =>
      draft.getTotalCredit() == 0 && draft.getCourseIdList().isEmpty;

  /// 加課不能走 `addCourseDetailByCourseInfo`：它一遇衝堂就整門拒絕，而模擬排課
  /// 就是要讓使用者先排進去、再看到哪裡撞。所以逐格自己放。
  static void addCourse(CourseTableJson draft, CourseMainInfoJson course) {
    final info = CourseInfoJson()..main = course;
    var placed = false;
    for (final day in CourseTableConflict.days) {
      for (final section
          in CourseTableConflict.sectionsOf(course.course.time[day])) {
        draft.courseInfoMap[day]![section] = info;
        placed = true;
      }
    }
    if (!placed) {
      // 沒有時間的課塞進 unKnown 那一欄，跟主課表同一套規則。
      draft.setCourseDetailByTime(Day.unKnown, SectionNumber.t_UnKnown, info);
    }
  }

  static void removeCourse(CourseTableJson draft, String courseId) {
    for (final day in Day.values) {
      draft.courseInfoMap[day]
          ?.removeWhere((_, course) => course.main.course.id == courseId);
    }
  }

  /// 隱藏週六日與 N/A-D 節的規則要同時看實際課表與草稿，不然草稿加了一門週六
  /// 的課，那一欄還是不會出現。
  static CourseTableJson merged(CourseTableJson? base, CourseTableJson draft) {
    final merged = CourseTableJson(
      courseSemester: draft.courseSemester,
      studentId: draft.studentId,
    );
    for (final source in [base, draft]) {
      if (source == null) continue;
      for (final day in Day.values) {
        final row = source.courseInfoMap[day];
        if (row == null) continue;
        row.forEach((section, course) {
          merged.courseInfoMap[day]![section] ??= course;
        });
      }
    }
    return merged;
  }

  static List<ConflictCell> conflictsOf(
          CourseTableJson? base, CourseTableJson draft) =>
      base == null ? const [] : CourseTableConflict.findConflicts(base, draft);

  /// 「3 處衝堂 · 三 3、四 6、四 7」。列出是哪幾格，使用者才知道要去看哪裡。
  static String conflictBanner(
      CourseTableControl control, List<ConflictCell> conflicts) {
    final where = conflicts
        .map((c) => '${control.getDayString(c.day.index)} '
            '${control.getSectionString(c.section.index)}')
        .toSet()
        .join('、');
    return sprintf(
        R.current.simulationConflictBanner, [conflicts.length, where]);
  }

  /// 設計稿把「草稿本身多少」與「加上實際課表之後多少」分成兩行——前者是這一頁
  /// 的產出，後者是使用者真正要問的問題。
  static String draftSummary(CourseTableJson draft) =>
      sprintf(R.current.simulationDraftSummary,
          [draft.getCourseIdList().length, draft.getTotalCredit()]);

  static String totalLine(CourseTableJson? base, CourseTableJson draft,
      List<ConflictCell> conflicts) {
    final total = (base?.getTotalCredit() ?? 0) + draft.getTotalCredit();
    final clash = conflicts.isEmpty
        ? R.current.simulationNoConflict
        : sprintf(R.current.simulationConflictCount, [conflicts.length]);
    return '${sprintf(R.current.simulationTotalSummary, [total])} · $clash';
  }

  /// 切換器與管理頁上的一行。衝堂對畫面上那一張實際課表算。
  static String listSummary(CourseTableJson? current, CourseTableJson draft) {
    final conflicts = conflictsOf(current, draft);
    return [
      sprintf(R.current.courseCount, [draft.getCourseIdList().length]),
      sprintf(R.current.creditCount, [draft.getTotalCredit()]),
      if (conflicts.isNotEmpty)
        sprintf(R.current.simulationConflictCount, [conflicts.length]),
    ].join(' · ');
  }

  /// 草稿裡選了哪些課，一門一列：一門跨三節的課在格子上是三格。
  static List<CourseMainInfoJson> coursesOf(CourseTableJson draft) {
    final seen = <String>{};
    return [
      for (final day in Day.values)
        for (final course
            in draft.courseInfoMap[day]?.values ?? const <CourseInfoJson>[])
          if (course.main.course.id.isNotEmpty &&
              seen.add(course.main.course.id))
            course.main,
    ];
  }

  /// 「CS3039701 · 3 學分 · 一 3·4」。
  static String courseSupporting(
      CourseTableControl control, CourseMainInfoJson course) {
    final id = course.course.id;
    final slots = control.slotLabel(course);
    return [
      if (id.isNotEmpty) id,
      if (course.course.credits.trim().isNotEmpty)
        sprintf(R.current.creditCount, [course.course.credits]),
      if (slots.isNotEmpty) slots,
    ].join(' · ');
  }
}
