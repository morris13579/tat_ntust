import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/section_time.dart';
import 'package:flutter_app/src/util/classroom_availability.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 一整天檢視：同一棟、同一天，換成看形狀。
///
/// **不寫課名**——課名不是使用者要的東西，點一列才看。空著留白，現在是一條
/// 線，排序由空得最久的排到最短。
///
/// 十四節在手機上放不下，所以格子區橫向捲，**教室編號那一欄釘住不動**：
/// 捲到後面幾節時還看得出自己在看哪一間。作法是把名稱那一欄畫在捲動內容
/// **上面**（Stack），捲動內容自己讓開同寬的左內距——兩個各自的
/// ScrollView 沒辦法共用一個 controller，那條路會讓上下兩半捲不同步。
class ClassroomDayGrid extends StatelessWidget {
  const ClassroomDayGrid({
    super.key,
    required this.vacancies,
    required this.section,
    this.onTapRoom,
  });

  final List<ClassroomVacancy> vacancies;

  /// 「現在」是第幾節，畫那條線用。
  final int section;

  final void Function(ClassroomVacancy vacancy)? onTapRoom;

  static const double _cellWidth = 26;
  static const double _cellHeight = 20;
  static const double _rowHeight = 28;
  static const double _gap = 3;
  static const double _nameWidth = 76;
  static const double _headerHeight = 22;
  static const double _groupHeight = 34;

  @override
  Widget build(BuildContext context) {
    final free = vacancies.where((v) => v.isFree).toList();
    final busy = vacancies.where((v) => !v.isFree).toList();
    final sorted = [
      ...ClassroomAvailability.byRunLength(free),
      ...ClassroomAvailability.byRunLength(busy),
    ];
    final groups = <(String, List<ClassroomVacancy>)>[
      if (free.isNotEmpty)
        (
          sprintf(R.current.classroomFreeGroup, [free.length]),
          sorted.take(free.length).toList()
        ),
      if (busy.isNotEmpty)
        (
          sprintf(R.current.classroomBusyGroup, [busy.length]),
          sorted.skip(free.length).toList()
        ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 10, 0, 14),
      decoration: BoxDecoration(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(TatTokens.radiusCard),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: _nameWidth, right: 14),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cellsHeader(context),
                    for (final (_, rooms) in groups) ...[
                      const SizedBox(height: _groupHeight),
                      for (final vacancy in rooms) _cellsRow(context, vacancy),
                    ],
                  ],
                ),
                _nowLine(context, groups),
              ],
            ),
          ),
          _frozenNames(context, groups),
        ],
      ),
    );
  }

  /// 「現在」那一條線。
  ///
  /// **從節次標題底下才開始畫。** 壓過標題的話那一欄的數字會被切成兩半，
  /// 而標題本身已經用顏色標出現在是哪一節了。它畫在捲動內容裡面，所以會
  /// 跟著格子一起左右移動。
  Widget _nowLine(
      BuildContext context, List<(String, List<ClassroomVacancy>)> groups) {
    if (section < 0 || section >= sectionTimes.length) {
      return const SizedBox.shrink();
    }
    var height = 0.0;
    for (final (_, rooms) in groups) {
      height += _groupHeight + rooms.length * _rowHeight;
    }
    // 最後一列底下的留白不算，線才不會多出一截。
    height -= (_rowHeight - _cellHeight) / 2;
    return Positioned(
      left: section * (_cellWidth + _gap) + _cellWidth / 2 - 1,
      top: _headerHeight,
      child: Container(
        width: 2,
        height: height < 0 ? 0 : height,
        color: context.scheme.primary,
      ),
    );
  }

  /// 釘住的那一欄。畫在捲動內容上面，所以要自己帶卡片底色把後面擋掉。
  Widget _frozenNames(
      BuildContext context, List<(String, List<ClassroomVacancy>)> groups) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: _nameWidth,
      child: Container(
        color: context.tokens.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: _headerHeight),
            for (final (label, rooms) in groups) ...[
              _groupLabel(context, label),
              for (final vacancy in rooms) _nameCell(context, vacancy),
            ],
          ],
        ),
      ),
    );
  }

  /// 分段標題比名稱那一欄寬，但它右邊本來就沒有格子，讓它畫出去即可。
  Widget _groupLabel(BuildContext context, String label) => SizedBox(
        height: _groupHeight,
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: context.text.labelMedium?.copyWith(
                    height: 1.3, color: context.scheme.onSurfaceVariant)),
          ),
        ),
      );

  Widget _nameCell(BuildContext context, ClassroomVacancy vacancy) {
    return SizedBox(
      height: _rowHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapRoom == null ? null : () => onTapRoom!(vacancy),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(vacancy.room.name,
                style: context.text.bodySmall?.copyWith(height: 1.3)),
          ),
        ),
      ),
    );
  }

  Widget _cellsHeader(BuildContext context) {
    return SizedBox(
      height: _headerHeight,
      child: Row(
        children: [
          for (var i = 0; i < sectionTimes.length; i++)
            Container(
              width: _cellWidth,
              margin: const EdgeInsets.only(right: _gap),
              alignment: Alignment.center,
              child: Text(
                sectionLabels[i],
                style: context.text.labelSmall?.copyWith(
                  height: 1.2,
                  color: i == section
                      ? context.scheme.primary
                      : context.scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cellsRow(BuildContext context, ClassroomVacancy vacancy) {
    // 整條格子也要點得開，不是只有左邊的教室編號——捲到後面幾節時使用者
    // 看的是格子，手指也落在格子上。
    return InkWell(
      onTap: onTapRoom == null ? null : () => onTapRoom!(vacancy),
      child: SizedBox(
        height: _rowHeight,
        child: Row(
          children: [
            for (var i = 0; i < sectionTimes.length; i++)
              Container(
                width: _cellWidth,
                height: _cellHeight,
                margin: const EdgeInsets.only(right: _gap),
                decoration: BoxDecoration(
                  color: _cellColor(context, vacancy, i),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _cellColor(BuildContext context, ClassroomVacancy vacancy, int index) {
    final tokens = context.tokens;
    final scheme = context.scheme;
    final slots = vacancy.room.slots;
    // 空格要在卡片上看得見，所以是頁面底色而不是卡片色——兩者反過來的話
    // 空堂會整片消失在白底裡。
    if (index >= slots.length) return tokens.page;
    final slot = slots[index];
    if (slot.isFree) return tokens.page;
    // 借出與排課分兩色：使用者看得出「這一格沒課但也去不了」。
    return slot.course.isEmpty && slot.marked
        ? tokens.warningContainer
        : scheme.primaryContainer;
  }
}
