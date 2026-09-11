import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/ui/pages/course_table/modal/semester_dialog.dart';
import 'package:flutter_app/ui/pages/course_table/modal/favorite_dialog.dart';
import 'package:flutter_app/ui/pages/course_table/modal/table_switcher_sheet.dart';
import 'package:flutter_app/ui/pages/course_table/manage_tables_page.dart';
import 'package:flutter_app/src/util/course_table_conflict.dart';
import 'package:intl/intl.dart';
import 'package:flutter_app/ui/pages/course_table/modal/course_cell_sheet.dart';
import 'package:flutter_app/ui/pages/course_table/modal/course_options_sheet.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/course_search_page.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/simulation_page.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/repository/ntust_repository.dart';
import 'package:flutter_app/src/util/course_table_share_codec.dart';
import 'package:flutter_app/src/util/shared_table_builder.dart';
import 'package:flutter_app/ui/pages/course_table/share/share_table_sheet.dart';
import 'package:flutter_app/ui/pages/course_table/share/scan_table_page.dart';
import 'package:flutter_app/ui/pages/course_table/share/import_confirm_sheet.dart';
import 'package:flutter_app/ui/pages/course_table/share/shared_table_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/src/util/my_toast.dart';
import 'dart:async';
import 'package:flutter_app/src/config/course_config.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/controller/course_table/course_controller.dart';
import 'package:flutter_app/src/enum/course_table_ui_state.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/page/base_page.dart';
import 'package:flutter_app/ui/components/widget_size_render_object.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';
import 'package:screenshot/screenshot.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

class CourseTablePage extends GetView<CourseController> {
  const CourseTablePage({super.key});

  @override
  Widget build(BuildContext context) {
    controller.refreshSemester();

    return Obx(() {
      final loaded = controller.isLoading.value == CourseTableUIState.success;
      return BasePage(
          title: R.current.titleCourse,
          subtitle: loaded ? _summary() : null,
          bottom: loaded ? _identityBar(context) : null,
          resizeToAvoidBottomInset: false,
          isLoading: controller.isLoading.value == CourseTableUIState.loading,
          isError: controller.isLoading.value == CourseTableUIState.fail,
          action: actionList(),
          child: contentView(context));
    });
  }

  List<Widget> actionList() {
    return [
      // 內層 Obx 只讀未讀數，未讀數變動時不會連整張課表一起重建。
      Obx(() {
        final unread = NotificationBadgeController.instance.unread.value;
        final icon = Icon(LucideIcons.bell, color: Get.iconColor);
        return IconButton(
          // 純圖示按鈕在螢幕閱讀器下只會唸「按鈕」，要靠 tooltip 補語意。
          tooltip: unread > 0
              ? sprintf(R.current.notificationUnreadTooltip, [unread])
              : R.current.announcementCenter,
          icon: unread > 0 ? Badge.count(count: unread, child: icon) : icon,
          iconSize: 24,
          splashRadius: 18,
          onPressed: () {
            unawaited(RouteUtils.toAnnouncementCenter());
          },
          enableFeedback: true,
        );
      }),
      Visibility(
        visible: AuthSession.instance.isSignedIn,
        child: IconButton(
          tooltip: R.current.refresh,
          icon: const Icon(LucideIcons.refreshCw),
          splashRadius: 18,
          iconSize: 24,
          onPressed: () {
            controller.getCourseTable(
              semesterSetting: controller.semesterSetting.value,
              refresh: true,
            );
          },
          enableFeedback: true,
        ),
      ),
      Visibility(
        visible: AuthSession.instance.isSignedIn,
        child: Builder(
          builder: (context) => IconButton(
            tooltip: R.current.courseTableOptions,
            icon: const Icon(LucideIcons.ellipsisVertical),
            splashRadius: 18,
            iconSize: 24,
            onPressed: () => unawaited(_showOptions(context)),
          ),
        ),
      )
    ];
  }

  /// 「N 門 · N 學分」。課表還沒載好就不顯示——數字從 0 跳到 6 比空白更吵。
  String _summary() => sprintf(R.current.courseTableSummary, [
        controller.courseTableControl.courseTable?.getCourseIdList().length ??
            0,
        controller.totalCredit,
      ]);

  /// 學號與學期切換，掛在標題列底下。
  ///
  /// 學號用等寬字並且只有一行：它是固定長度的識別碼，換行或縮放都只會讓人
  /// 更難核對。
  PreferredSizeWidget _identityBar(BuildContext context) {
    return PreferredSize(
      // 40 而不是 52：這一列只有一行字與一顆學期鈕，多出來的高度會讓標題與
      // 課表之間空一大塊。
      preferredSize: const Size.fromHeight(40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                controller.studentId.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.tabular(
                  context.text.bodyLarge ?? const TextStyle(),
                ).copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: context.tokens.page,
              borderRadius: BorderRadius.circular(TatTokens.radiusButton),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => unawaited(_showSemesterList(context)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: 34,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          controller.semesterString.value,
                          style: AppTypography.tabular(
                            context.text.bodyMedium ?? const TextStyle(),
                          ).copyWith(
                            fontWeight: FontWeight.w500,
                            color: context.scheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Icon(LucideIcons.chevronDown,
                            size: 16, color: context.scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget contentView(BuildContext context) {
    return WidgetSizeOffsetWrapper(
      onSizeChange: (Size size) {
        // 只扣星期列：學號那一列已經搬到 AppBar 的 bottom，不在這個量到的框
        // 裡面。以前還扣它一次，九列加起來就少 40，底下空一條看得見的白。
        controller.courseHeight.value = (size.height - CourseConfig.dayHeight) /
            CourseConfig.showCourseTableNum;
      },
      child: Column(
        children: <Widget>[
          Expanded(
            child: controller.isLoading.value != CourseTableUIState.success
                ? const SizedBox()
                : _buildListView(context),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context) {
    return SingleChildScrollView(
      child: Screenshot(
        controller: controller.screenshotController,
        child: Column(
          children: List.generate(
            controller.courseTableControl.getSectionIntList.length + 1,
            (index) {
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: ScaleAnimation(
                  child: FadeInAnimation(
                    child: (index == 0)
                        ? _buildDay()
                        : _buildCourseTable(context, index - 1),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDay() {
    List<Widget> widgetList = [];
    widgetList.add(Container(
      width: CourseConfig.sectionWidth,
    ));
    for (int i in controller.courseTableControl.getDayIntList) {
      widgetList.add(
        Expanded(
          child: Text(
            controller.courseTableControl.getDayString(i),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Container(
      color: Get.theme.scaffoldBackgroundColor
          .withAlpha(CourseConfig.courseTableWithAlpha),
      height: CourseConfig.dayHeight,
      child: Row(
        children: widgetList,
      ),
    );
  }

  Widget _buildCourseTable(BuildContext context, int index) {
    var courseTableControl = controller.courseTableControl;
    int section = courseTableControl.getSectionIntList[index];

    List<Widget> widgetList = [];
    widgetList.add(
      Container(
        width: CourseConfig.sectionWidth,
        alignment: Alignment.center,
        child: Text(
          courseTableControl.getSectionString(section),
          textAlign: TextAlign.center,
        ),
      ),
    );

    for (int day in courseTableControl.getDayIntList) {
      CourseInfoJson? courseInfo =
          courseTableControl.getCourseInfo(day, section);
      Color color = courseTableControl.getCourseInfoColor(day, section);
      courseInfo = courseInfo ?? CourseInfoJson();
      widgetList.add(
        Expanded(
          child: courseInfo.isEmpty
              ? const SizedBox()
              : Container(
                  padding: const EdgeInsets.all(1),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        backgroundColor: color,
                        elevation: 0),
                    child: AutoSizeText(
                      courseInfo.main.course.name,
                      style: TextStyle(
                          color: UIUtils.getOnColor(color),
                          fontSize: 14,
                          height: 1.2),
                      minFontSize: 10,
                      maxLines: 3,
                      textAlign: TextAlign.center,
                    ),
                    onPressed: () {
                      unawaited(_showCourseDetailDialog(
                          context, section, courseInfo!));
                    },
                  ),
                ),
        ),
      );
    }

    return Container(
      color: UIUtils.getListColor(index),
      height: controller.courseHeight.value,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widgetList,
      ),
    );
  }

  /// **哪一個 widget 出現是這一頁的事。**
  ///
  /// controller 只做資料操作、把結果回傳給這裡；controller 自己呼叫 `Get.dialog`
  /// 或 `RouteUtils` 會讓 `lib/src/controller` 反向 import `lib/ui`。

  Future<void> _showSemesterList(BuildContext context) async {
    final semesterList = await controller.loadSemesterList();
    if (!context.mounted) return;
    final selected = await showSemesterSheet(
      context: context,
      semesterList: semesterList,
      selected: controller.semesterSetting.value,
    );
    if (selected == null) return;
    await controller.getCourseTable(semesterSetting: selected);
  }

  Future<void> _showCourseDetailDialog(
      BuildContext context, int section, CourseInfoJson courseInfo) async {
    // 選單只回報使用者選了什麼，動作等它關掉之後才做：同一時間只允許一個
    // 浮層，導頁與移除都會再開一層。
    final action = await showCourseCellSheet(
      context: context,
      courseInfo: courseInfo,
      time: controller.courseTableControl.getTimeString(section),
      color: controller.courseTableControl
          .getCourseInfoColor(section ~/ 100, section % 100),
    );
    if (action == null) return;

    switch (action) {
      case CourseCellAction.moodle:
        _openCourseData(courseInfo);
      case CourseCellAction.detail:
        _openCourseDetail(courseInfo);
      case CourseCellAction.editCourseId:
        await editCourseCellId(courseInfo);
      case CourseCellAction.remove:
        if (await showCourseRemoveDialog(courseInfo.main.course.name)) {
          await controller.removeCourse(courseInfo);
        }
    }
  }

  Future<void> _showOptions(BuildContext context) async {
    final option = await showCourseOptionsSheet(
      context: context,
      canImport: true,
    );
    if (option == null) return;
    switch (option) {
      case CourseTableOption.favorite:
        if (!context.mounted) return;
        await _showSwitcher(context);
      case CourseTableOption.importCourse:
        await _addCustomCourse();
      case CourseTableOption.scan:
        if (!context.mounted) return;
        await _scanTable(context);
      case CourseTableOption.share:
        if (!context.mounted) return;
        await _shareTable(context);
      case CourseTableOption.exportImage:
        if (!context.mounted) return;
        await _exportImage(context);
      case CourseTableOption.androidWidget:
        await controller.setWidget();
    }
  }

  /// 課號為空的自訂課程沒有詳情可以看。
  bool _hasCourseId(CourseInfoJson courseInfo) {
    final course = courseInfo.main.course;
    if (course.id.isEmpty) {
      MyToast.show(course.name + R.current.noSupport);
      return false;
    }
    return true;
  }

  void _openCourseData(CourseInfoJson courseInfo) {
    // 先關掉詳情對話框再導頁。
    Get.back();
    if (!_hasCourseId(courseInfo)) return;
    RouteUtils.toCourseDataPage(courseInfo);
  }

  void _openCourseDetail(CourseInfoJson courseInfo) {
    if (!_hasCourseId(courseInfo)) return;
    RouteUtils.toCourseDetailPage(controller.currentSemester, courseInfo);
  }

  /// 課表切換器。設計稿把「我的課表／他人課表／模擬課表」放在同一個選單裡，
  /// 原本的「載入常用課表」只看得到第一種。
  Future<void> _showSwitcher(BuildContext context) async {
    await ExtraTableStore.instance.load();
    if (!context.mounted) return;
    final mine = controller.favorites;
    final choice = await showTableSwitcherSheet(
      context: context,
      myTables: mine,
      shared: ExtraTableStore.instance.shared,
      drafts: ExtraTableStore.instance.drafts,
      currentLabel: _currentTableLabel(),
      labelOf: favoriteLabel,
      summaryOf: favoriteSummary,
      importedAtOf: _importedAt,
      draftSummaryOf: _draftSummary,
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case MyTableChoice(:final table):
        await controller.applyFavorite(table);
      case DraftChoice(:final draft):
        await _openSimulation(context, draft: draft);
      case SharedChoice(:final shared):
        unawaited(Get.to(() => SharedTablePage(shared: shared)));
      case NewDraftChoice():
        await _openSimulation(context);
      case ManageTablesChoice():
        await _openManageTables(context);
    }
  }

  String _currentTableLabel() =>
      favoriteLabelOf(controller.studentId.value, controller.currentSemester);

  String _importedAt(ExtraTable table) =>
      '${table.table.courseSemester.year}-${table.table.courseSemester.semester}'
      ' · ${sprintf(R.current.courseCount, [
            table.table.getCourseIdList().length
          ])}'
      ' · ${sprintf(R.current.importedOn, [
            DateFormat.Md().format(table.savedAt)
          ])}';

  String _draftSummary(ExtraTable draft) {
    final base = controller.courseTableData;
    final conflicts = base == null
        ? const <ConflictCell>[]
        : CourseTableConflict.findConflicts(base, draft.table);
    final parts = [
      sprintf(R.current.courseCount, [draft.table.getCourseIdList().length]),
      sprintf(R.current.creditCount, [draft.table.getTotalCredit()]),
      if (conflicts.isNotEmpty)
        sprintf(R.current.simulationConflictCount, [conflicts.length]),
    ];
    return parts.join(' · ');
  }

  /// 分享自己的課表。存成圖片交給系統的分享面板——寫進相簿要一個本專案刻意
  /// 沒有的權限。
  Future<void> _shareTable(BuildContext context) async {
    final table = controller.courseTableData;
    if (table == null) {
      MyToast.show(R.current.unknownError);
      return;
    }
    await showShareTableSheet(
      context: context,
      table: table,
      onSaveImage: (png) => _sharePng(context, png, 'tat-course-table-qr.png'),
      onCopied: () => MyToast.show(R.current.shareTableCodeCopied),
    );
  }

  /// 整週課表的 PNG。截的是畫面上那一張表，所以看到什麼就匯出什麼。
  Future<void> _exportImage(BuildContext context) async {
    final png = await controller.screenshotController.capture(pixelRatio: 3);
    if (png == null) {
      MyToast.show(R.current.unknownError);
      return;
    }
    if (!context.mounted) return;
    await _sharePng(context, png, 'tat-course-table.png');
  }

  Future<void> _sharePng(
      BuildContext context, Uint8List png, String name) async {
    final origin = _shareOrigin(context);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(png);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      sharePositionOrigin: origin,
    ));
  }

  /// 分享面板的錨點。
  ///
  /// iOS 26 起 iPhone 的 UIActivityViewController 也有 popover presentation
  /// controller，share_plus 那段「只有 iPad 才需要 sharePositionOrigin」的檢查
  /// 因此在 iPhone 上也會擋下來，回 PlatformException 而不是打開面板——畫面上
  /// 看起來就是點了沒反應。錨點必須落在 FlutterViewController 的 view 之內。
  static Rect _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// 掃描 → 確認 → 還原課名 → 存起來 → 直接打開。
  ///
  /// 課表在確認的當下就已經畫得出來（QR 帶了時間），還原課名只是補資料，
  /// 失敗也照樣匯入——不能因為查不到課名就讓整份掃描白做。
  Future<void> _scanTable(BuildContext context) async {
    SharedTablePayload? payload;
    await Get.to(() => ScanTablePage(
          onDetected: (value) => payload = value,
          onError: MyToast.show,
        ));
    if (payload == null || !context.mounted) return;
    // lookup 傳的是裸的 tear-off：學期由選單自己從 payload 算，這裡沒有把
    // 目前選到的學期傳錯進去的機會。
    if (!await showImportConfirmSheet(
      context: context,
      payload: payload!,
      lookup: NtustRepository.instance.lookupSharedCourses,
    )) {
      return;
    }

    // 先用 QR 裡的東西存起來、直接打開——格子當下就對了。課名與教室在那一頁
    // 進去之後才補，不讓使用者對著轉圈等好幾秒。
    final table = SharedTableBuilder.build(payload!);
    final shared = ExtraTable(
      id: 'shared-${payload!.studentId}-${payload!.semesterCode}',
      label: payload!.studentId,
      table: table,
      savedAt: DateTime.now(),
      payload: CourseTableShareCodec.encodePayload(table),
    );
    await ExtraTableStore.instance.load();
    await ExtraTableStore.instance.upsertShared(shared);
    MyToast.show(sprintf(R.current.importDone, [shared.label]));
    unawaited(Get.to(() => SharedTablePage(
          shared: shared,
          onRestore: (onProgress) =>
              NtustRepository.instance.restoreSharedCourses(
            table.courseSemester,
            table.getCourseIdList(),
            onProgress: onProgress,
          ),
        )));
  }

  Future<void> _openManageTables(BuildContext context) async {
    await Get.to(() => ManageTablesPage(
          myTables: controller.favorites,
          currentLabel: _currentTableLabel(),
          labelOf: favoriteLabel,
          summaryOf: favoriteSummary,
          importedAtOf: _importedAt,
          draftSummaryOf: _draftSummary,
          onDeleteMine: controller.deleteFavorite,
          confirmDelete: showFavoriteDeleteDialog,
          onScan: () => unawaited(_scanTable(context)),
        ));
  }

  /// 導入其他課程。跟模擬排課的搜尋頁是同一頁——同樣看得到衝堂、同樣的篩選，
  /// 差別只在加進去的是實際課表而不是草稿。
  Future<void> _addCustomCourse() async {
    final table = controller.courseTableData;
    if (table == null) {
      MyToast.show(R.current.unknownError);
      return;
    }
    await Get.to(() => CourseSearchPage(
          editor: SimulationEditor(
            draft: table,
            // 加到實際課表時「底圖」就是它自己，再傳一次會讓每一門課都跟自己
            // 撞。衝堂改由 draft 那一邊算。
            base: null,
            semester: table.courseSemester,
            add: (course) => unawaited(controller.addCustomCourse(course)),
            remove: (id) => unawaited(controller.removeCourseById(id)),
            contains: (id) => table.getCourseIdList().contains(id),
          ),
          search: (filter) =>
              controller.searchCourse(table.courseSemester, filter),
          loadColleges: controller.loadColleges,
          loadDepartments: controller.loadDepartments,
        ));
  }

  /// 開一份模擬課表。
  ///
  /// 每一份草稿綁一個學年度：querycourse 是分學期的，草稿的學期跟搜尋的學期
  /// 不一致的話，排進去的課根本不存在於那一學期。新增時先問學年度，之後那一份
  /// 就只查得到該學期的課。
  ///
  /// 底圖是「同一學期的實際課表」。選了一個沒有下載過的學期就沒有底圖，那正是
  /// 「從空白課表自由安排」的情況。
  Future<void> _openSimulation(BuildContext context,
      {ExtraTable? draft}) async {
    await ExtraTableStore.instance.load();
    var target = draft;
    if (target == null) {
      // 學期清單來自 querycourse 而不是使用者自己的紀錄：新學期在選課開始前
      // 就查得到，等成績或選課紀錄長出來才排課已經來不及。查不到（沒網路）
      // 才退回自己的學期，至少還排得了手上這幾個學期。
      var semesterList =
          await NtustRepository.instance.getQueryCourseSemesters();
      if (semesterList.isEmpty) {
        semesterList = await controller.loadSemesterList();
      }
      if (!context.mounted) return;
      final chosen = await showSemesterSheet(
        context: context,
        semesterList: semesterList,
        selected: controller.currentSemester,
      );
      if (chosen == null) return;
      final studentId = controller.studentId.value;
      final id = 'draft-$studentId-$chosen';
      target = ExtraTableStore.instance.findDraft(id) ??
          ExtraTable(
            id: id,
            label: sprintf(R.current.simulationDraftLabel,
                ['${chosen.year}-${chosen.semester}']),
            table:
                CourseTableJson(courseSemester: chosen, studentId: studentId),
            savedAt: DateTime.now(),
          );
    }
    final bound = target;
    final semester = bound.table.courseSemester;
    // 只有同一學期的實際課表才能當底圖。
    // firstWhereOrNull 需要 collection 套件，這裡自己找一輪就好。
    CourseTableJson? base;
    for (final table in controller.favorites) {
      if (table.studentId == bound.table.studentId &&
          table.courseSemester == semester) {
        base = table;
        break;
      }
    }
    unawaited(Get.to(() => SimulationPage(
          draft: bound,
          base: base,
          openSearch: (context, editor) =>
              Get.to(() => CourseSearchPage(
                    editor: editor,
                    search: (filter) =>
                        controller.searchCourse(editor.semester, filter),
                    loadColleges: controller.loadColleges,
                    loadDepartments: controller.loadDepartments,
                  )) ??
              Future.value(),
        )));
  }
}
