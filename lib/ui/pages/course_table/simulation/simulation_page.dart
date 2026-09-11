import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/util/course_table_conflict.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/notice_bar.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/draft_course_sheet.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/simulation_table.dart';
import 'package:sprintf/sprintf.dart';

/// 模擬排課。
///
/// 草稿是**另一份** [CourseTableJson]，不會寫回實際課表——這一頁做的每一件事
/// 都只動 [ExtraTableStore] 的草稿清單。畫面上同時看得到實際課表（實心）與草稿
/// （虛線），撞在一起的格子標紅。
///
/// 搜尋頁怎麼開由呼叫端注入：這一頁不 import route_utils（見
/// docs/ARCHITECTURE.md「UI 慣例」）。
class SimulationPage extends StatefulWidget {
  const SimulationPage({
    super.key,
    required this.draft,
    required this.base,
    required this.openSearch,
  });

  /// 這一份草稿。
  final ExtraTable draft;

  /// 使用者實際的課表，當成底圖；null 代表還沒載入課表。
  final CourseTableJson? base;

  /// 開搜尋頁。回傳使用者這一趟加了哪些課——加完才一起寫檔，中途返回不留半份。
  final Future<void> Function(BuildContext context, SimulationEditor editor)
      openSearch;

  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

/// 交給搜尋頁的編輯介面。搜尋頁只透過這個改草稿，不直接碰 store。
class SimulationEditor {
  SimulationEditor({
    required this.draft,
    required this.base,
    required this.semester,
    required this.add,
    required this.remove,
    required this.contains,
  });

  final CourseTableJson draft;
  final CourseTableJson? base;

  /// 這一份草稿綁定的學年度。搜尋只能查這一學期的課。
  final SemesterJson semester;
  final void Function(CourseMainInfoJson course) add;
  final void Function(String courseId) remove;
  final bool Function(String courseId) contains;
}

class _SimulationPageState extends State<SimulationPage> {
  /// 固定列高：這一頁是整週捲動看的，不像主課表要塞滿一屏。
  static const double _rowHeight = 56;

  final CourseTableControl _control = CourseTableControl();

  /// 底部摘要可以收起來：課表本身才是這一頁的主角。

  CourseTableJson get _draft => widget.draft.table;

  @override
  void initState() {
    super.initState();
    _refreshControl();
  }

  /// 隱藏週六日與 N/A-D 節的規則要同時看實際課表與草稿，不然草稿加了一門週六
  /// 的課，那一欄還是不會出現。
  void _refreshControl() {
    final merged = CourseTableJson(
      courseSemester: _draft.courseSemester,
      studentId: _draft.studentId,
    );
    for (final source in [widget.base, _draft]) {
      if (source == null) continue;
      for (final day in Day.values) {
        final row = source.courseInfoMap[day];
        if (row == null) continue;
        row.forEach((section, course) {
          merged.courseInfoMap[day]![section] ??= course;
        });
      }
    }
    _control.set(merged);
  }

  List<ConflictCell> get _conflicts => widget.base == null
      ? const []
      : CourseTableConflict.findConflicts(widget.base!, _draft);

  @override
  Widget build(BuildContext context) {
    final conflicts = _conflicts;
    return Scaffold(
      appBar: mainAppbar(
        title: widget.draft.label,
        subtitle: R.current.simulationSubtitle,
        isShowBack: true,
      ),
      body: Column(
        children: [
          if (conflicts.isNotEmpty) _banner(conflicts),
          Expanded(child: _table()),
          _summary(conflicts),
        ],
      ),
    );
  }

  /// 「3 處衝堂 · 三 3、四 6、四 7」。列出是哪幾格，使用者才知道要去看哪裡。
  Widget _banner(List<ConflictCell> conflicts) {
    final where = conflicts
        .map((c) => '${_control.getDayString(c.day.index)} '
            '${_control.getSectionString(c.section.index)}')
        .toSet()
        .join('、');
    return NoticeBar(
      message: sprintf(
          R.current.simulationConflictBanner, [conflicts.length, where]),
      kind: NoticeKind.error,
    );
  }

  Widget _table() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: SimulationTable(
        control: _control,
        rowHeight: _rowHeight,
        cellOf: _cellOf,
        onTapCourse: _onTapCourse,
      ),
    );
  }

  SimulationCell _cellOf(int day, int section) {
    final key = Day.values[day];
    final number = SectionNumber.values[section];
    return SimulationCell(
      real: widget.base?.courseInfoMap[key]?[number],
      draft: _draft.courseInfoMap[key]?[number],
    );
  }

  void _onTapCourse(CourseInfoJson course, bool isDraft) {
    if (!isDraft) return;
    // 草稿裡的課點一下就拿掉：這一頁的全部意義就是快速試排。
    _removeCourse(course.main.course.id);
  }

  /// 底部摘要。設計稿把「草稿本身多少」與「加上實際課表之後多少」分成兩行——
  /// 前者是這一頁的產出，後者是使用者真正要問的問題。
  Widget _summary(List<ConflictCell> conflicts) {
    final scheme = context.scheme;
    final text = context.text;
    final draftCredit = _draft.getTotalCredit();
    final total = (widget.base?.getTotalCredit() ?? 0) + draftCredit;
    return Material(
      color: context.tokens.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => unawaited(_openDraftList(conflicts)),
                child: Row(
                  children: [
                    Icon(LucideIcons.flaskConical,
                        size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sprintf(R.current.simulationDraftSummary,
                                [_draft.getCourseIdList().length, draftCredit]),
                            style: AppTypography.tabular(text.titleSmall!)
                                .copyWith(color: scheme.onSurface),
                          ),
                          const SizedBox(height: 2),
                          if (draftCredit == 0 &&
                              _draft.getCourseIdList().isEmpty)
                            Text(
                              R.current.simulationEmptyHint,
                              style: text.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            )
                          else
                            Text(
                              '${sprintf(R.current.simulationTotalSummary, [
                                    total
                                  ])} · ${conflicts.isEmpty ? R.current.simulationNoConflict : sprintf(R.current.simulationConflictCount, [
                                      conflicts.length
                                    ])}',
                              style: AppTypography.tabular(text.bodySmall!)
                                  .copyWith(
                                      color: conflicts.isEmpty
                                          ? scheme.onSurfaceVariant
                                          : scheme.error),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(LucideIcons.chevronUp,
                        size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: TatTokens.heightButton,
                child: FilledButton.icon(
                  onPressed: _openSearch,
                  icon: const Icon(LucideIcons.search, size: 18),
                  label: Text(R.current.courseSearchTitle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 摘要那一列點下去看選了什麼。
  ///
  /// 這裡本來是摺疊：點一下只多顯示／少顯示一行字，而且藏掉的正是「加上實際
  /// 課表共幾學分、幾處衝堂」——使用者開這一頁就是要看那一行。改成攤開草稿的
  /// 課，那個往上的箭頭才對得起它給的暗示。
  Future<void> _openDraftList(List<ConflictCell> conflicts) async {
    await showDraftCourseSheet(
      context: context,
      draft: _draft,
      control: _control,
      conflictIds: conflicts.map((c) => c.overlay.main.course.id).toSet(),
      onRemove: _removeCourse,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openSearch() async {
    await widget.openSearch(
      context,
      SimulationEditor(
        draft: _draft,
        base: widget.base,
        semester: _draft.courseSemester,
        add: _addCourse,
        remove: _removeCourse,
        contains: _contains,
      ),
    );
    if (!mounted) return;
    setState(_refreshControl);
    unawaited(_save());
  }

  bool _contains(String courseId) =>
      _draft.getCourseIdList().contains(courseId);

  /// 加課不能走 `addCourseDetailByCourseInfo`：它一遇衝堂就整門拒絕，而這一頁
  /// 就是要讓使用者先排進去、再看到哪裡撞。所以逐格自己放。
  void _addCourse(CourseMainInfoJson course) {
    final info = CourseInfoJson()..main = course;
    var placed = false;
    for (final day in CourseTableConflict.days) {
      for (final section
          in CourseTableConflict.sectionsOf(course.course.time[day])) {
        _draft.courseInfoMap[day]![section] = info;
        placed = true;
      }
    }
    if (!placed) {
      // 沒有時間的課塞進 unKnown 那一欄，跟主課表同一套規則。
      _draft.setCourseDetailByTime(Day.unKnown, SectionNumber.t_UnKnown, info);
    }
    setState(_refreshControl);
  }

  void _removeCourse(String courseId) {
    for (final day in Day.values) {
      final row = _draft.courseInfoMap[day];
      if (row == null) continue;
      row.removeWhere((_, course) => course.main.course.id == courseId);
    }
    setState(_refreshControl);
    unawaited(_save());
  }

  Future<void> _save() {
    widget.draft.savedAt = DateTime.now();
    return ExtraTableStore.instance.upsertDraft(widget.draft);
  }
}
