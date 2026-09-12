import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/src/controller/classroom/classroom_controller.dart';
import 'package:flutter_app/src/enum/classroom_view.dart';
import 'package:flutter_app/src/model/classroom/classroom_option.dart';
import 'package:flutter_app/src/model/classroom/classroom_usage_json.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/classroom_availability.dart';
import 'package:flutter_app/ui/components/chip/tat_filter_chip.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/components/page/section_empty_state.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/pages/classroom/classroom_time_sheet.dart';
import 'package:flutter_app/ui/pages/classroom/widgets/classroom_day_grid.dart';
import 'package:flutter_app/ui/pages/classroom/widgets/classroom_other_buildings.dart';
import 'package:flutter_app/ui/pages/classroom/widgets/classroom_room_sheet.dart';
import 'package:flutter_app/ui/pages/classroom/widgets/classroom_room_tile.dart';
import 'package:flutter_app/ui/pages/classroom/widgets/classroom_section_bar.dart';
import 'package:flutter_app/ui/pages/classroom/widgets/classroom_view_toggle.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';

/// 空教室。
///
/// 借用系統回答的是「每一間教室的一整天」，這一頁把它反過來：**先回答
/// 「現在」，再讓你往後看**。
///
/// 一頁兩種檢視，切換器與大樓、時段放在一起——它切的是「怎麼看這一棟」，
/// 所以不放 app bar。**切換不重設任何選擇**：大樓、日期、節次、連續節數都
/// 留著，只有第三列（清單是連續節數篩選、一整天是圖示說明）會換。
class ClassroomPage extends StatefulWidget {
  const ClassroomPage({
    super.key,
    required this.errorBuilder,
    this.initialDate,
    this.initialSection,
  });

  /// 失敗時要畫什麼。由呼叫端注入而不是直接用 `ErrorPage`，
  /// 見 docs/ARCHITECTURE.md「UI 慣例」。
  final Widget Function(String message, Future<void> Function() onRetry)
      errorBuilder;

  /// 從課表的空堂進來時帶的時段。null 就是「現在」。
  final DateTime? initialDate;
  final int? initialSection;

  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage> {
  late final ClassroomController _controller = ClassroomController();

  @override
  void initState() {
    super.initState();
    // 請求發在這裡而不是 build()：每一次 rebuild 都重打一次是個災難。
    unawaited(_start());
  }

  Future<void> _start() async {
    final date = widget.initialDate;
    final section = widget.initialSection;
    if (date != null && section != null) {
      await _controller.setTime(date, section);
    }
    await _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.page,
      appBar: baseAppbar(title: R.current.classroomTitle),
      body: Obx(() {
        final campuses = _controller.campuses.value;
        if (campuses == null) {
          return const LoadingPage(isLoading: true, isShowBackground: false);
        }
        if (campuses is Failed<List<ClassroomCampusJson>>) {
          return widget.errorBuilder(
              campuses.reason.message, () => _controller.init());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildingRow(context),
            ClassroomSectionBar(
              section: _controller.section,
              onChange: _changeTime,
            ),
            _thirdRow(context),
            Expanded(child: _content(context)),
          ],
        );
      }),
    );
  }

  /// 大樓 + 檢視切換。
  Widget _buildingRow(BuildContext context) {
    final building = _controller.currentBuilding;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          // Expanded 而不是 Flexible＋Spacer：那兩個的 flex 都是 1，會把剩餘
          // 空間對半分，切換器因此停在離右緣一段距離的地方。
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: _pickBuilding,
                borderRadius: BorderRadius.circular(TatTokens.radiusButton),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          building?.name ?? R.current.classroomPickBuilding,
                          style:
                              context.text.titleMedium?.copyWith(height: 1.3),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(LucideIcons.chevronDown,
                          size: 18, color: context.scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ClassroomViewToggle(
            value: _controller.view.value,
            onChanged: (view) => unawaited(_controller.setView(view)),
          ),
        ],
      ),
    );
  }

  /// 第三列：清單是連續節數篩選，一整天是圖示說明。**兩者不同時出現。**
  Widget _thirdRow(BuildContext context) {
    if (_controller.view.value == ClassroomView.day) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            _legend(context, context.tokens.page,
                R.current.classroomLegendFree),
            const SizedBox(width: 14),
            _legend(context, context.scheme.primaryContainer,
                R.current.classroomLegendClass),
            const SizedBox(width: 14),
            _legend(context, context.tokens.warningContainer,
                R.current.classroomLegendBooked),
          ],
        ),
      );
    }
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final filter in ClassroomRunFilter.values) ...[
            TatFilterChip(
              label: _filterLabel(filter),
              selected: _controller.runFilter.value == filter,
              onTap: () => _controller.runFilter.value = filter,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _filterLabel(ClassroomRunFilter filter) => switch (filter) {
        ClassroomRunFilter.any => R.current.classroomRunAny,
        ClassroomRunFilter.twoSections => R.current.classroomRunTwo,
        ClassroomRunFilter.threeSections => R.current.classroomRunThree,
        ClassroomRunFilter.allDay => R.current.classroomRunAllDay,
      };

  Widget _legend(BuildContext context, Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: context.text.labelMedium?.copyWith(
                  height: 1.3, color: context.scheme.onSurfaceVariant)),
        ],
      );

  Widget _content(BuildContext context) {
    // revision 讀一下，日期／節次換了畫面才會重畫。
    _controller.revision;
    if (_controller.isLoadingCurrent) {
      return const LoadingPage(isLoading: true, isShowBackground: false);
    }
    final result = _controller.current;
    if (result == null) {
      return const SizedBox.shrink();
    }
    if (result is Failed<ClassroomUsageJson>) {
      return widget.errorBuilder(
          _fetchFailedMessage(result.reason.message), _controller.refresh);
    }
    if (_controller.isClosedDay) {
      // 空狀態也要接得上「其他大樓」與抓取時間：這一棟今天沒資料時，使用者
      // 的下一步多半是換一棟，不該逼他再開一次大樓選單。
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _closedDay(context),
          _otherBuildings(),
          _footer(context),
        ],
      );
    }

    return _controller.view.value == ClassroomView.day
        ? _dayView(context)
        : _listView(context);
  }

  /// 抓不到時說出是哪一棟、什麼時候試的——「載入失敗」四個字幫不上忙。
  String _fetchFailedMessage(String fallback) {
    final building = _controller.currentBuilding;
    if (building == null) return fallback;
    return sprintf(R.current.classroomFetchFailed,
        [building.name, classroomClock(DateTime.now())]);
  }

  /// 這一天站台一列都沒回。**這不是錯誤，也不是「全部空著」**——借用系統只
  /// 排上課日，那一天有沒有人借用它根本沒講，畫成全空會是憑空捏造。
  Widget _closedDay(BuildContext context) {
    final building = _controller.currentBuilding;
    return SectionEmptyState(
      icon: LucideIcons.calendarDays,
      message: '${sprintf(R.current.classroomClosedTitle, [
            building?.name ?? ''
          ]).trim()}\n${R.current.classroomClosedBody}',
    );
  }

  Widget _listView(BuildContext context) {
    final rooms = _controller.freeRooms;
    final grouped = ClassroomAvailability.byFloor(rooms);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
          child: Text(
            sprintf(R.current.classroomFreeSummary,
                [_controller.roomCount, _controller.freeCount]),
            style: context.text.bodySmall?.copyWith(
                height: 1.35, color: context.scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 10),
        if (rooms.isEmpty) _full(context),
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 4, 8),
            child: Text(
              entry.key == null
                  ? ''
                  : sprintf(R.current.classroomFloor, [entry.key]),
              style: context.text.labelMedium?.copyWith(
                  height: 1.3, color: context.scheme.onSurfaceVariant),
            ),
          ),
          for (var i = 0; i < entry.value.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            ClassroomRoomTile(
              vacancy: entry.value[i],
              index: i,
              length: entry.value.length,
              onTap: () => unawaited(showClassroomRoomSheet(
                context: context,
                room: entry.value[i].room,
                section: _controller.section,
              )),
            ),
          ],
        ],
        _otherBuildings(),
        _footer(context),
      ],
    );
  }

  /// 全滿是正常結果，不是錯誤——所以沒有插圖也沒有驚嘆號，只給下一步。
  Widget _full(BuildContext context) {
    final building = _controller.currentBuilding;
    final next = _controller.section + 1;
    return Column(
      children: [
        const SizedBox(height: 18),
        Text(
          sprintf(R.current.classroomFullTitle, [building?.name ?? '']).trim(),
          style: context.text.titleSmall?.copyWith(height: 1.3),
        ),
        const SizedBox(height: 4),
        Text(
          sprintf(R.current.classroomFullBody, [_controller.roomCount]),
          style: context.text.bodySmall?.copyWith(
              height: 1.35, color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 主題只設了 filled 與 text 兩種按鈕，沒有 outlined——用
            // OutlinedButton 會吃到 Material 的預設值（膠囊外框、另一個高度），
            // 和旁邊那顆對不齊。全 App 的「主＋次」是兩顆 FilledButton，
            // 次要那顆換成 surfaceContainerHighest（見 tat_dialog.dart）。
            if (next < sectionTimes.length) ...[
              FilledButton(
                onPressed: () =>
                    unawaited(_controller.setTime(_controller.date, next)),
                child: Text(sprintf(
                    R.current.classroomSeeSection, [sectionLabels[next]])),
              ),
              const SizedBox(width: 10),
            ],
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.scheme.surfaceContainerHighest,
                foregroundColor: context.scheme.onSurface,
              ),
              onPressed: _pickBuilding,
              child: Text(R.current.classroomChangeBuilding),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _dayView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ClassroomDayGrid(
          vacancies: _controller.vacancies,
          section: _controller.section,
          onTapRoom: (vacancy) => unawaited(showClassroomRoomSheet(
            context: context,
            room: vacancy.room,
            section: _controller.section,
          )),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_otherBuildings(), _footer(context)],
          ),
        ),
      ],
    );
  }

  Widget _otherBuildings() => ClassroomOtherBuildings(
        buildings: _controller.buildings
            .where((b) => b.code != _controller.buildingCode.value)
            .toList(),
        usage: _controller.usage,
        loading: _controller.loading,
        onSelect: (code) => unawaited(_controller.selectBuilding(code)),
      );

  Widget _footer(BuildContext context) {
    final fetched = _controller.current?.dataOrNull?.fetchedAt;
    if (fetched == null) return const SizedBox.shrink();
    final building = _controller.currentBuilding;
    final isDay = _controller.view.value == ClassroomView.day;
    // 跟著內容捲到底，不釘在畫面底部：它講的是「這份資料什麼時候抓的」，
    // 屬於這份資料的結尾，不是一條常駐工具列。
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isDay
                  ? sprintf(R.current.classroomDayFetchedAt,
                      [classroomClock(fetched)])
                  : sprintf(R.current.classroomFetchedAt,
                      [building?.name ?? '', classroomClock(fetched)]).trim(),
              style: context.text.labelSmall?.copyWith(
                  height: 1.3, color: context.scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => unawaited(_controller.refresh()),
            child: Text(R.current.classroomRefresh),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBuilding() async {
    final code = await showTatSingleSelectSheet<String>(
      context: context,
      title: R.current.classroomPickBuilding,
      selected: _controller.buildingCode.value,
      options: [
        for (final building in _controller.buildings)
          TatSheetOption(label: building.name, value: building.code),
      ],
    );
    if (code != null) await _controller.selectBuilding(code);
  }

  Future<void> _changeTime() async {
    final picked = await showClassroomTimeSheet(
      context: context,
      date: _controller.date,
      section: _controller.section,
    );
    if (picked != null) {
      await _controller.setTime(picked.date, picked.section);
    }
  }
}
