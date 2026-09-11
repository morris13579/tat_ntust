import 'package:flutter_app/src/controller/course_data/course_data_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/section_empty_state.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_info_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/course_section_list.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 一列在它那一串裡的位置（決定圓角）要等整串組完才知道，所以先收成
/// 「給我序號我就畫得出來」的函式，最後再一次結算。
typedef _Row = Widget Function(BuildContext context, int index, int length);

class CourseDirectoryPage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  /// 三個（或兩個）分頁共用的狀態。頁面在進入時就把所有請求發完，
  /// 所以每個分頁只負責畫自己那一份。
  final CourseDataController controller;

  const CourseDirectoryPage(
    this.courseInfo, {
    required this.controller,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseDirectoryPageState();
}

class _CourseDirectoryPageState extends State<CourseDirectoryPage>
    with AutomaticKeepAliveClientMixin {
  /// 主題式一次最多先露幾個項目，其餘收在「顯示其餘 N 個項目」後面。
  static const int _previewCount = 3;

  /// null 代表還在載入。請求不能寫進 build()，否則每一次 rebuild（切主題、
  /// 切語言、鍵盤彈出、上層 setState）都會重跑整段流程。
  Rxn<Result<List<MoodleCoreCourseGetContents>>> get _state =>
      widget.controller.directory;

  // 沒有 initState 觸發請求：由頁面在進入時一次發完三個（或兩個），
  // 見 CourseDataController.loadAll / CourseDetailController.loadAll。

  final TextEditingController _query = TextEditingController();

  /// 展開了的段（key 是 section id）。
  final Set<int> _expanded = {};

  /// 已經按過「顯示其餘 N 個檔案」的段。
  final Set<int> _showAll = {};

  /// 本週那一張預設是展開的，所以記的是「有沒有被收起來」。放進 [_expanded]
  /// 的話「預設展開」得在 build 裡寫入集合，那會和使用者的收合互相蓋掉。
  bool _currentWeekOpen = true;

  bool _showEmptyWeeks = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() => widget.controller.loadDirectory();

  void _toggle(Set<int> set, int id) => setState(() {
        if (!set.remove(id)) set.add(id);
      });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ResultView<List<MoodleCoreCourseGetContents>>(
      state: _state,
      onRetry: _load,
      errorBuilder: (message) => ErrorPage(errorMsg: message),
      builder: (data) => GestureDetector(
        // 空白處收鍵盤。translucent 才收得到落在清單空隙上的點擊，而列自己的
        // InkWell 在手勢競技場裡比較深，照樣先贏。
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _searchField(),
            Expanded(child: buildTree(data)),
          ],
        ),
      ),
    );
  }

  void _clearQuery() => setState(() => _query.clear());

  /// 釘在分頁列底下的檔名篩選。整棵樹本來就在記憶體裡，篩選不發請求。
  ///
  /// 形狀跟資訊系統的搜尋欄一致（見 SubSystemSearchField）：底色交給
  /// InputDecorationTheme，外面那層只跟著頁面底色，不自成一塊色帶。
  Widget _searchField() {
    // Material 而不是 ColoredBox：TextField 需要 Material 祖先，靠外層剛好有
    // Scaffold 才成立的話，這一頁被單獨放到別的地方就會炸。
    return Material(
      color: context.tokens.page,
      child: Padding(
        // 上下都 12。下面這 12 一定要留在這一層：清單的 padding 是會跟著捲走
        // 的，交給它的話一捲動第一列就貼上輸入框的下緣。
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: TextField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          // 檔名是單行的，換行只會把輸入框撐高；鍵盤右下角給搜尋。
          textInputAction: TextInputAction.search,
          style: context.text.bodyLarge?.copyWith(height: 1.2),
          decoration: InputDecoration(
            hintText: R.current.searchFileName,
            prefixIcon: const Icon(LucideIcons.search, size: 18),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 42, minHeight: 24),
            // 只在有字的時候才出現，空欄位上放一顆清除鈕沒有意義。
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: R.current.cancel,
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: _clearQuery,
                  ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 42, minHeight: 24),
          ),
        ),
      ),
    );
  }

  /// 週次／主題就地展開，不換頁：一段裡的討論區、作業、測驗與檔案各有各的
  /// 入口，[CourseModuleRow] 依 modname 決定圖示與尾端動作。
  Widget buildTree(List<MoodleCoreCourseGetContents> directoryList) {
    final tree = CourseSectionTree.of(directoryList);
    final query = _query.text.trim();
    final items = <WidgetBuilder>[];

    if (query.isNotEmpty) {
      _buildSearchResult(items, tree, query);
    } else if (tree.weekly) {
      _buildWeekly(items, tree);
    } else {
      _buildTopics(items, tree);
    }

    return ListView.builder(
      // 上方不留白：輸入框那一層已經給了固定的 12，這裡再給就會變成 24。
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index](context),
    );
  }

  /// 把一串列結算成畫得出來的東西：到這一刻才知道總共幾列。
  void _flush(List<WidgetBuilder> items, List<_Row> run) {
    final length = run.length;
    for (var i = 0; i < length; i++) {
      final row = run[i];
      final index = i;
      items.add((context) => row(context, index, length));
    }
    run.clear();
  }

  // ---------------------------------------------------------------- 搜尋

  void _buildSearchResult(
      List<WidgetBuilder> items, CourseSectionTree tree, String query) {
    final hits = tree.search(query);
    if (hits.isEmpty) {
      items.add((context) => SectionEmptyState(
            icon: LucideIcons.search,
            message: R.current.fileSearchNoResult,
          ));
      return;
    }
    // 命中的列留在原本那一段底下：只有一串檔名看不出它是哪一週的。
    final run = <_Row>[];
    for (var i = 0; i < hits.length; i++) {
      final (section, modules) = hits[i];
      final first = i == 0;
      items.add((context) => SectionHeader(title: section.title, first: first));
      _moduleRows(run, modules);
      _flush(items, run);
    }
  }

  // ---------------------------------------------------------------- 週次

  void _buildWeekly(List<WidgetBuilder> items, CourseSectionTree tree) {
    items.add((context) => _stats(sprintf(R.current.fileStatsWeekly,
        [tree.totalFiles, tree.sectionsWithContent])));

    final run = <_Row>[];
    final current = tree.currentWeek;
    if (current != null) {
      run.add((context, index, length) => CourseSectionRow(
            key: ValueKey('section-${current.raw.id}'),
            title: current.title,
            badge: R.current.thisWeek,
            summary: current.summaryText,
            // 本週那一張的檔案就攤在底下，右邊再放一個數字是多的。
            highlight: true,
            expanded: _currentWeekOpen,
            onTap: () => setState(() => _currentWeekOpen = !_currentWeekOpen),
            index: index,
            length: length,
          ));
      if (_currentWeekOpen) _moduleRows(run, current.modules);
      _flush(items, run);
    }

    final others = tree.otherWithContent;
    if (others.isNotEmpty) {
      items.add((context) => SectionHeader(
            title: current == null
                ? R.current.weeksWithFiles
                : R.current.otherWeeksWithFiles,
          ));
      _sectionRows(run, others, folderIcon: false);
      _flush(items, run);
    }

    final empty = tree.empty;
    if (empty.isEmpty) return;
    items.add((context) => const SizedBox(height: 20));
    run.add((context, index, length) => CourseDisclosureRow(
          label: _showEmptyWeeks
              ? R.current.hideEmptyWeeks
              : sprintf(R.current.showEmptyWeeks, [empty.length]),
          expanded: _showEmptyWeeks,
          onTap: () => setState(() => _showEmptyWeeks = !_showEmptyWeeks),
          index: index,
          length: length,
        ));
    if (_showEmptyWeeks) _sectionRows(run, empty, folderIcon: false);
    _flush(items, run);
  }

  // ---------------------------------------------------------------- 主題式

  void _buildTopics(List<WidgetBuilder> items, CourseSectionTree tree) {
    final topics = tree.nonEmpty;
    items.add((context) => _stats(
        sprintf(R.current.fileStatsTopic, [tree.totalFiles, topics.length])));
    items.add((context) => SectionHeader(title: R.current.topic, first: true));

    final run = <_Row>[];
    _sectionRows(run, topics, folderIcon: true, limit: _previewCount);
    _flush(items, run);
  }

  // ------------------------------------------------------------ 共用的組裝

  /// 一段一列，展開的段把模組接在自己底下。[limit] 有值時，展開的段先只露
  /// 這麼多列，其餘收在一列連結後面。
  void _sectionRows(
    List<_Row> run,
    List<CourseSection> sections, {
    required bool folderIcon,
    int? limit,
  }) {
    for (final section in sections) {
      final id = section.raw.id;
      final expanded = _expanded.contains(id);
      run.add((context, index, length) => CourseSectionRow(
            key: ValueKey('section-$id'),
            title: section.title,
            summary: section.summaryText,
            // 數字是這一段的項目數，不是檔案數：分組已經改成「有沒有內容」，
            // 作業與連結也算，右邊那個數字要跟著它才對得起來。
            count: section.modules.isEmpty ? null : section.modules.length,
            showFolderIcon: folderIcon,
            expanded: expanded,
            onTap: () => _toggle(_expanded, id),
            index: index,
            length: length,
          ));
      if (!expanded) continue;

      final visible = _visibleModules(section, limit);
      _moduleRows(run, visible);

      final hidden = section.modules.length - visible.length;
      if (hidden == 0) continue;
      run.add((context, index, length) => CourseDisclosureRow(
            label: sprintf(R.current.showRemainingFiles, [hidden]),
            showChevron: false,
            accent: true,
            onTap: () => _toggle(_showAll, id),
            index: index,
            length: length,
          ));
    }
  }

  List<Modules> _visibleModules(CourseSection section, int? limit) {
    if (limit == null || _showAll.contains(section.raw.id)) {
      return section.modules;
    }
    return section.modules.take(limit).toList();
  }

  void _moduleRows(List<_Row> run, List<Modules> modules) {
    for (final module in modules) {
      run.add((context, index, length) => CourseModuleRow(
            key: ValueKey('module-${module.id}'),
            module: module,
            index: index,
            length: length,
            onTap: (m) =>
                CourseModuleActions(widget.courseInfo).handle(context, m),
          ));
    }
  }

  Widget _stats(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
      child: Text(
        label,
        style: AppTypography.tabular(
            (context.text.bodySmall ?? const TextStyle())
                .copyWith(color: context.scheme.onSurfaceVariant, height: 1.4)),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
