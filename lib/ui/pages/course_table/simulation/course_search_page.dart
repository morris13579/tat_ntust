import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/tat_progress.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course/course_department.dart';
import 'package:flutter_app/src/model/course/course_query_filter.dart';
import 'package:flutter_app/src/model/course_table/course_time.dart';
import 'package:flutter_app/src/util/course_table_conflict.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/ui/components/chip/tat_filter_chip.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/input/search_bar.dart';
import 'package:flutter_app/ui/components/page/section_empty_state.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/course_filter_page.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/course_slot_picker_page.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/simulation_page.dart';
import 'package:sprintf/sprintf.dart';

/// 模擬排課的搜尋課程頁。
///
/// 跟「導入其他課程」那一頁的差別是這裡**看得到衝堂**：每一張卡片自己算會不會
/// 撞到（實際課表 ＋ 草稿已經加的課），撞到就在卡片上寫是跟哪一門撞、撞在哪一節。
/// 沒有這一行，使用者要一路加完再回課表才看得出排不排得下。
///
/// 搜尋怎麼打由呼叫端注入：這一頁不碰 repository 也不 import route_utils。
class CourseSearchPage extends StatefulWidget {
  const CourseSearchPage({
    super.key,
    required this.editor,
    required this.search,
    required this.loadColleges,
    required this.loadDepartments,
  });

  final SimulationEditor editor;

  /// 丟一組查詢條件回一批課。學期由呼叫端在 closure 裡綁好。
  final Future<List<CourseMainInfoJson>> Function(CourseQueryFilter filter)
      search;

  /// 系所篩選的兩層資料來源。
  final Future<List<CollegeJson>> Function() loadColleges;
  final Future<List<DepartmentJson>> Function(String collegeNo) loadDepartments;

  @override
  State<CourseSearchPage> createState() => _CourseSearchPageState();
}

class _CourseSearchPageState extends State<CourseSearchPage> {
  final CourseTableControl _control = CourseTableControl();

  List<CourseMainInfoJson> _results = [];
  bool _loading = false;
  bool _searched = false;

  /// 設計稿的「只看不衝堂」。加退選現場最常問的就是「哪些我排得進去」，
  /// 所以預設就打開——排不進去的課列出來也只是讓人再篩一次。想看全部再關掉。
  ///
  /// 這一個是**畫面上**篩的：衝不衝堂伺服器不知道，`OnlyNode` 送 1 會回非
  /// JSON（見 docs/QUERYCOURSE_API.md），沒有伺服器端的節次篩選可用。
  bool _hideConflict = true;

  /// 想上的節次。空的就是不篩。
  ///
  /// 這一項**不進 [CourseQueryFilter]**：querycourse 的節次篩選不在伺服器端，
  /// 官方前端也是拿回結果之後自己比對的。混進 filter 會讓 `isEmpty` 誤判成
  /// 「有條件」而送出一次沒有意義的查詢。
  Set<CourseSlot> _slots = {};

  /// 這一個是**伺服器**篩的，每一項都對得上 querycourse 真的吃的參數。
  CourseQueryFilter _filter = const CourseQueryFilter();

  final TextEditingController _keyword = TextEditingController();

  /// 一進來就先列出使用者自己系所這學期的課，不要開一張空白頁。
  ///
  /// 不能用空條件自動查：`CourseConnector.searchCourse` 對空條件直接回空陣列，
  /// 而且全校一學期有 4282 門，真的拉下來也不是使用者要的。系所只有幾十門
  /// （1151 的 CS 是 63 門），剛好。
  ///
  /// 課號前兩碼就是系所代碼，所以從使用者現有的課表取眾數就得到系所，不必再問
  /// 一次伺服器。關鍵字欄位會一起填上那兩碼——不然畫面上會冒出一批沒來由的
  /// 課，使用者也不知道要清掉什麼才能看到全部。
  @override
  void initState() {
    super.initState();
    final prefix = _homeDepartmentPrefix();
    if (prefix == null) return;
    _keyword.text = prefix;
    _filter = _filter.copyWith(courseNo: prefix);
    // 這裡不能走 _run：它開頭就 setState，而 initState 跑在 build 階段裡，
    // 等於在建構途中標記自己需要重建。欄位直接指定，只有回應回來才 setState。
    _loading = true;
    _searched = true;
    unawaited(_fetch(_filter));
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  String? _homeDepartmentPrefix() {
    final counts = <String, int>{};
    for (final table in [widget.editor.base, widget.editor.draft]) {
      for (final id in table?.getCourseIdList() ?? const <String>[]) {
        if (id.length < 2) continue;
        final prefix = id.substring(0, 2).toUpperCase();
        // 數字開頭的不是系所代碼（通識與共同科目就長這樣）。
        if (!RegExp(r'^[A-Z]{2}$').hasMatch(prefix)) continue;
        counts[prefix] = (counts[prefix] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mainAppbar(title: R.current.courseSearchTitle, isShowBack: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CourseSearchBar(controller: _keyword, onSubmit: _onSubmit),
          ),
          _filters(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TatFilterChip(
              icon: LucideIcons.filter,
              label: R.current.courseSearchFilter,
              selected: _filter.hasRefinements,
              onTap: () => unawaited(_openFilter()),
            ),
            TatFilterChip(
              label: R.current.courseSearchHideConflict,
              selected: _hideConflict,
              onTap: () => setState(() => _hideConflict = !_hideConflict),
            ),
            TatFilterChip(
              label: R.current.courseSearchSlot,
              selected: _slots.isNotEmpty,
              onTap: () => unawaited(_openSlotPicker()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSlotPicker() async {
    final next = await Navigator.of(context).push<Set<CourseSlot>>(
        MaterialPageRoute(
            builder: (context) => CourseSlotPickerPage(selected: _slots)));
    if (next == null || !mounted) return;
    // 純本地篩選，不必重查。
    setState(() => _slots = next);
  }

  /// 改完條件就直接重查：篩選是伺服器端的，不重查畫面不會變。
  ///
  /// 沒打關鍵字也要查——「英語授課的通識」本身就是一個完整的問題，不該逼使用者
  /// 先隨便打一個字。條件全空才不查，那會讓伺服器回整個學期。
  Future<void> _openFilter() async {
    final next =
        await Navigator.of(context).push<CourseQueryFilter>(MaterialPageRoute(
            builder: (context) => CourseFilterPage(
                  filter: _filter,
                  loadColleges: widget.loadColleges,
                  loadDepartments: widget.loadDepartments,
                )));
    if (next == null || !mounted) return;
    setState(() => _filter = next);
    if (!next.isEmpty) await _run(next);
  }

  Widget _body() {
    if (_loading) return const Center(child: TatProgress());
    if (!_searched) {
      return SectionEmptyState(
        icon: LucideIcons.search,
        message: R.current.courseSearchTitle,
      );
    }
    final visible = _visible();
    if (visible.isEmpty) {
      return SectionEmptyState(
        icon: LucideIcons.search,
        message: R.current.courseSearchNotFound,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      itemCount: visible.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          index == 0 ? _countLine() : _card(visible[index - 1]),
    );
  }

  /// 「18 門 · 其中 11 門與課表衝堂」。第二段只有真的有衝堂時才出現。
  Widget _countLine() {
    final clashes = _results.where((c) => _conflictsOf(c).isNotEmpty).length;
    final parts = [
      sprintf(R.current.courseSearchResultSummary, [_results.length]),
      if (clashes > 0)
        sprintf(R.current.courseSearchConflictSummary, [clashes]),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        parts.join(' · '),
        style: AppTypography.tabular(context.text.bodySmall!)
            .copyWith(color: context.scheme.onSurfaceVariant),
      ),
    );
  }

  List<CourseMainInfoJson> _visible() => _results
      .where((c) => !_hideConflict || _conflictsOf(c).isEmpty)
      .where(_fitsSlots)
      .toList();

  /// 這門課的每一格都要落在勾選的節次裡。
  ///
  /// 用「完全落在」而不是「有交集」：勾 1、2 是因為那兩節有空，一門橫跨 1–3
  /// 的課列出來也排不進去。沒有排定時間的課（querycourse 的 `Node` 是 null，
  /// 例如體育校隊）不算「在某幾節」，一律排除。
  bool _fitsSlots(CourseMainInfoJson course) {
    if (_slots.isEmpty) return true;
    final cells = <CourseSlot>{};
    for (final day in CourseTableConflict.days) {
      for (final section
          in CourseTableConflict.sectionsOf(course.course.time[day])) {
        cells.add((day, section));
      }
    }
    if (cells.isEmpty) return false;
    return cells.every(_slots.contains);
  }

  /// 這門課會撞到什麼。實際課表與草稿都要看：草稿裡剛加的課也算數。
  List<ConflictCell> _conflictsOf(CourseMainInfoJson course) {
    final cells = <ConflictCell>[];
    final base = widget.editor.base;
    if (base != null) {
      cells.addAll(CourseTableConflict.conflictsOf(base, course));
    }
    cells.addAll(CourseTableConflict.conflictsOf(widget.editor.draft, course));
    return cells;
  }

  Widget _card(CourseMainInfoJson course) {
    final scheme = context.scheme;
    final text = context.text;
    final added = widget.editor.contains(course.course.id);
    final conflicts = _conflictsOf(course);
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(TatTokens.radiusCard),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.course.name,
                    style: text.titleSmall?.copyWith(color: scheme.onSurface)),
                const SizedBox(height: 4),
                Text(
                  _metaOf(course),
                  style: AppTypography.tabular(text.bodySmall!)
                      .copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                ),
                Text(
                  _timeOf(course),
                  style: AppTypography.tabular(text.bodySmall!)
                      .copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                ),
                for (final line in _conflictLines(conflicts)) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(LucideIcons.triangleAlert,
                          size: 14, color: scheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(line,
                            style:
                                text.bodySmall?.copyWith(color: scheme.error)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _toggle(course, added),
        ],
      ),
    );
  }

  /// 「AC5009701 · 3 學分 · 選修」。
  ///
  /// 必選修來自 querycourse 的 `RequireOption`，值域只有 R / E（實測 1151 學期
  /// 1222 / 3060 門）；認不得的值就不顯示，不要硬猜一個。
  String _metaOf(CourseMainInfoJson course) {
    final parts = [
      course.course.id,
      if (course.course.credits.trim().isNotEmpty)
        sprintf(R.current.creditCount, [course.course.credits]),
      if (_requireOptionLabel(course.course.category) != null)
        _requireOptionLabel(course.course.category)!,
    ];
    return parts.join(' · ');
  }

  static String? _requireOptionLabel(String requireOption) =>
      switch (requireOption.trim().toUpperCase()) {
        'R' => R.current.courseRequired,
        'E' => R.current.courseElective,
        _ => null,
      };

  String _timeOf(CourseMainInfoJson course) {
    final parts = [
      if (course.getTeacherName().trim().isNotEmpty) course.getTeacherName(),
      if (_control.slotLabel(course).isNotEmpty) _control.slotLabel(course),
      if (course.getClassroomName().trim().isNotEmpty)
        course.getClassroomName(),
    ];
    return parts.join(' · ');
  }

  /// 「與 離散數學（三 9、四 3·4） 衝堂」。
  ///
  /// 同一門課撞好幾節只寫一行，但**要把撞到的節次全部列出來**：只印第一節會讓
  /// 使用者以為只差一節，退掉一節就排得進去。
  List<String> _conflictLines(List<ConflictCell> conflicts) {
    final byCourse = <String, List<ConflictCell>>{};
    for (final cell in conflicts) {
      byCourse.putIfAbsent(cell.base.main.course.id, () => []).add(cell);
    }
    return [
      for (final cells in byCourse.values)
        sprintf(R.current.courseSearchConflictWith, [
          cells.first.base.main.course.name,
          _slotsOfCells(cells),
        ]),
    ];
  }

  /// 撞到的格子照星期併成「三 9、四 3·4」。
  String _slotsOfCells(List<ConflictCell> cells) {
    final byDay = <Day, List<String>>{};
    for (final cell in cells) {
      byDay
          .putIfAbsent(cell.day, () => [])
          .add(_control.getSectionString(cell.section.index));
    }
    return [
      for (final entry in byDay.entries)
        '${_control.getDayString(entry.key.index)} ${entry.value.join('·')}',
    ].join('、');
  }

  Widget _toggle(CourseMainInfoJson course, bool added) {
    final scheme = context.scheme;
    return IconButton(
      tooltip:
          added ? R.current.simulationRemoveCourse : R.current.courseSearchAdd,
      onPressed: () => setState(() {
        if (added) {
          widget.editor.remove(course.course.id);
        } else {
          widget.editor.add(course);
        }
      }),
      icon: Icon(added ? LucideIcons.check : LucideIcons.plus),
      color: added ? scheme.primary : scheme.onSurfaceVariant,
    );
  }

  Future<void> _onSubmit(String keyword) {
    setState(() => _filter = _filter.copyWith(courseNo: keyword));
    return _run(_filter.copyWith(courseNo: keyword));
  }

  Future<void> _run(CourseQueryFilter filter) async {
    setState(() {
      _loading = true;
      _searched = true;
    });
    await _fetch(filter);
  }

  Future<void> _fetch(CourseQueryFilter filter) async {
    final results = await widget.search(filter);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }
}
