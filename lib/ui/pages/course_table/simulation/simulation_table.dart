import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/course_config.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/course_table_control.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/course_table/simulation/dashed_border.dart';

/// 一格裡要畫的東西。
class SimulationCell {
  const SimulationCell({this.real, this.draft});

  /// 實際課表上的課。
  final CourseInfoJson? real;

  /// 草稿加的課。
  final CourseInfoJson? draft;

  bool get isEmpty => real == null && draft == null;

  /// 兩門**不同**的課搶同一格。
  ///
  /// 同一門課同時在實際課表與草稿裡不算衝堂——那只是「這門課我已經在修了」，
  /// 判定要跟 `CourseTableConflict.findConflicts` 一致，否則格子標紅、上面的
  /// 橫幅卻說沒有衝堂。
  bool get isConflict =>
      real != null &&
      draft != null &&
      real!.main.course.id != draft!.main.course.id;
}

/// 模擬排課的課表本體。
///
/// 跟主課表的差別只在一格裡畫什麼：草稿的課用虛線框、衝堂的格子用 error 色並
/// 且上下擺兩門課。格線、節次欄、星期列都沿用 [CourseTableControl] 的設定，
/// 隱藏週六日與 N/A-D 節的規則才跟主課表一致。
class SimulationTable extends StatelessWidget {
  const SimulationTable({
    super.key,
    required this.control,
    required this.cellOf,
    required this.rowHeight,
    this.onTapCourse,
  });

  final CourseTableControl control;

  final SimulationCell Function(int day, int section) cellOf;

  final double rowHeight;

  final void Function(CourseInfoJson course, bool isDraft)? onTapCourse;

  @override
  Widget build(BuildContext context) {
    final sections = control.getSectionIntList;
    return Column(
      children: [
        _header(context),
        for (var i = 0; i < sections.length; i++) _row(context, sections[i], i),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return SizedBox(
      height: CourseConfig.dayHeight,
      child: Row(
        children: [
          const SizedBox(width: CourseConfig.sectionWidth),
          for (final day in control.getDayIntList)
            Expanded(
              child: Text(
                control.getDayString(day),
                textAlign: TextAlign.center,
                style: context.text.bodySmall
                    ?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int section, int index) {
    return Container(
      color: UIUtils.getListColor(index),
      height: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: CourseConfig.sectionWidth,
            child: Center(
              child: Text(
                control.getSectionString(section),
                style: context.text.bodySmall
                    ?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ),
          ),
          for (final day in control.getDayIntList)
            Expanded(child: _cell(context, cellOf(day, section))),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, SimulationCell cell) {
    if (cell.isEmpty) return const SizedBox();
    if (cell.isConflict) {
      // 衝堂：上下各一門，紅框把整格圈起來。只畫一門的話使用者看不出是跟誰撞。
      return Padding(
        padding: const EdgeInsets.all(1),
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: context.scheme.error,
            radius: TatTokens.radiusButton,
          ),
          child: Column(
            children: [
              Expanded(child: _mini(context, cell.real!, isDraft: false)),
              Expanded(child: _mini(context, cell.draft!, isDraft: true)),
            ],
          ),
        ),
      );
    }
    final draft = cell.draft != null;
    return Padding(
      padding: const EdgeInsets.all(1),
      child: _block(context, (cell.real ?? cell.draft)!, isDraft: draft),
    );
  }

  /// 一般的一門課。草稿是虛線框加淡底，實際課表是實心色塊，跟主課表一致。
  Widget _block(BuildContext context, CourseInfoJson course,
      {required bool isDraft}) {
    final scheme = context.scheme;
    final color = _colorOf(course);
    final body = Material(
      color: isDraft ? color.withValues(alpha: 0.22) : color,
      borderRadius: BorderRadius.circular(TatTokens.radiusButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(TatTokens.radiusButton),
        onTap: onTapCourse == null ? null : () => onTapCourse!(course, isDraft),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AutoSizeText(
              course.main.course.name,
              style: TextStyle(
                color: isDraft ? scheme.onSurface : UIUtils.getOnColor(color),
                fontSize: 12,
                height: 1.2,
              ),
              minFontSize: 8,
              maxLines: 3,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
    if (!isDraft) return body;
    return CustomPaint(
      painter: DashedBorderPainter(
        color: color,
        radius: TatTokens.radiusButton,
      ),
      child: body,
    );
  }

  /// 衝堂格裡的半格。字更小，因為一格要塞兩門。
  ///
  /// [isDraft] 要照這半格自己的身分傳：上半是實際課表的課、下半才是草稿的。
  /// 兩邊都傳 true 的話，點實際課表那一門會被當成「移除草稿」。
  Widget _mini(BuildContext context, CourseInfoJson course,
      {required bool isDraft}) {
    final scheme = context.scheme;
    return InkWell(
      onTap: onTapCourse == null ? null : () => onTapCourse!(course, isDraft),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AutoSizeText(
            course.main.course.name,
            style: context.text.bodySmall?.copyWith(
              color: scheme.error,
              height: 1.15,
            ),
            minFontSize: 7,
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Color _colorOf(CourseInfoJson course) =>
      control.colorMap[course.main.course.id] ?? Colors.blueGrey.shade200;
}
