import 'package:flutter/material.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/page/section_empty_state.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 草稿裡目前選了哪些課。
///
/// 底部摘要只寫得下「幾門、幾學分」，看不到選了什麼；格子上的課名又被切成
/// 一節一格，一門跨三節的課要自己拼。這裡用一列一門課的方式攤開。
///
/// 移除也放在這裡。格子上點一下就刪太容易誤觸，而且點實際課表的課什麼都不會
/// 發生——同一個手勢兩種結果，其中一種還是破壞性的。
Future<void> showDraftCourseSheet({
  required BuildContext context,
  required CourseTableJson draft,
  required CourseTableControl control,
  required Set<String> conflictIds,
  required void Function(String courseId) onRemove,
}) =>
    showTatContentSheet<void>(
      context: context,
      title: R.current.simulationDraftListTitle,
      showClose: true,
      builder: (context) => _DraftCourseList(
        draft: draft,
        control: control,
        conflictIds: conflictIds,
        onRemove: onRemove,
      ),
    );

class _DraftCourseList extends StatefulWidget {
  const _DraftCourseList({
    required this.draft,
    required this.control,
    required this.conflictIds,
    required this.onRemove,
  });

  final CourseTableJson draft;
  final CourseTableControl control;
  final Set<String> conflictIds;
  final void Function(String courseId) onRemove;

  @override
  State<_DraftCourseList> createState() => _DraftCourseListState();
}

class _DraftCourseListState extends State<_DraftCourseList> {
  /// 移掉的課號。直接讀 draft 會拿到已經被改掉的清單，但這一頁是 sheet，
  /// 呼叫端的 setState 推不動它，所以自己記一份。
  final Set<String> _removed = {};

  List<CourseMainInfoJson> get _courses {
    final seen = <String>{};
    final courses = <CourseMainInfoJson>[];
    for (final day in Day.values) {
      final row = widget.draft.courseInfoMap[day];
      if (row == null) continue;
      for (final course in row.values) {
        final id = course.main.course.id;
        if (id.isEmpty || _removed.contains(id) || !seen.add(id)) continue;
        courses.add(course.main);
      }
    }
    return courses;
  }

  @override
  Widget build(BuildContext context) {
    final courses = _courses;
    if (courses.isEmpty) {
      return SectionEmptyState(
        icon: LucideIcons.flaskConical,
        message: R.current.simulationEmptyHint,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < courses.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _row(courses[i], i, courses.length),
        ],
      ],
    );
  }

  Widget _row(CourseMainInfoJson course, int index, int length) {
    final scheme = context.scheme;
    final text = context.text;
    final id = course.course.id;
    final clashes = widget.conflictIds.contains(id);
    final slots = widget.control.slotLabel(course);
    final supporting = [
      if (id.isNotEmpty) id,
      if (course.course.credits.trim().isNotEmpty)
        sprintf(R.current.creditCount, [course.course.credits]),
      if (slots.isNotEmpty) slots,
    ].join(' · ');

    return Material(
      color: context.tokens.card,
      borderRadius: UIUtils.getBorderRadius(index, length),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    course.course.name,
                    style: text.bodyLarge?.copyWith(
                        height: 1.4,
                        color: clashes ? scheme.error : scheme.onSurface),
                  ),
                  if (supporting.isNotEmpty)
                    Text(
                      supporting,
                      style: AppTypography.tabular(text.bodySmall!)
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18),
              color: scheme.onSurfaceVariant,
              tooltip: R.current.simulationRemoveCourse,
              onPressed: () {
                widget.onRemove(id);
                setState(() => _removed.add(id));
              },
            ),
          ],
        ),
      ),
    );
  }
}
