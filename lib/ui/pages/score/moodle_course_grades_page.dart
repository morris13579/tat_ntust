import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/controller/score_page/moodle_course_grades_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_overview_course_grades.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/note_icon.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/section_empty_state.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

/// 「Moodle 目前成績」：這學期每一門課在 Moodle 上的即時總分。點一列開那門課的
/// Moodle 成績分頁，那一段導頁由呼叫端注入，見 docs/ARCHITECTURE.md「UI 慣例」。
/// 清單是頁面中段的一個區塊（標題與說明卡片一直都在），所以失敗畫面是
/// InlineErrorView 而不是注入的整頁錯誤畫面，同「公告與通知」頁。
class MoodleCourseGradesPage extends StatefulWidget {
  const MoodleCourseGradesPage({
    super.key,
    required this.onOpenCourse,
    this.controller,
  });

  final Future<void> Function(MoodleCourseGradeItem course) onOpenCourse;

  /// 測試注入預先載好的狀態；注入時這一頁不會自己再發請求。
  final MoodleCourseGradesController? controller;

  @override
  State<MoodleCourseGradesPage> createState() => _MoodleCourseGradesPageState();
}

class _MoodleCourseGradesPageState extends State<MoodleCourseGradesPage> {
  late final MoodleCourseGradesController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? MoodleCourseGradesController();
    if (_ownsController) unawaited(_controller.load());
  }

  @override
  void dispose() {
    // 注入進來的那一顆屬於呼叫端（測試），不歸這裡收。
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 學期掛在 AppBar 而不是頁面內再來一行標題：這一頁只有一個區塊，
      // 內外兩個同名標題等於白佔一行。
      appBar: baseAppbar(
        title: R.current.moodleCourseGrades,
        action: [
          Center(child: Obx(() => _semesterLabel(context))),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView(
          // 清單空或是錯誤畫面時也要拉得動。
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
          children: [
            _hintCard(context),
            const SizedBox(height: 10),
            ResultView<MoodleCourseGradeList>(
              shrinkWrap: true,
              state: _controller.grades,
              onRetry: _controller.refresh,
              errorBuilder: (message) => InlineErrorView(
                message: message,
                onRetry: _controller.refresh,
              ),
              builder: _buildList,
            ),
          ],
        ),
      ),
    );
  }

  /// 資料還沒到時不佔位：學期只有接上課程清單之後才知道。
  Widget _semesterLabel(BuildContext context) {
    final semester = _controller.grades.value?.dataOrNull?.semester;
    if (semester == null || semester.isEmpty) return const SizedBox.shrink();
    return Text(
      '${semester.year}-${semester.semester}',
      style: context.text.bodySmall
          ?.copyWith(color: context.scheme.onSurfaceVariant),
    );
  }

  /// 「這是 Moodle 的即時總分、不是正式成績」這句話要排在任何數字之前。
  Widget _hintCard(BuildContext context) {
    final scheme = context.scheme;
    final style =
        context.text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return SectionCard([
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoteIcon(LucideIcons.info,
              style: style, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(R.current.moodleCourseGradesHint, style: style),
          ),
        ],
      ),
    ]);
  }

  Widget _buildList(MoodleCourseGradeList data) {
    if (data.courses.isEmpty) {
      return SectionEmptyState(
        icon: LucideIcons.graduationCap,
        message: R.current.moodleCourseGradesEmpty,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < data.courses.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _buildRow(context, data.courses[i], i, data.courses.length),
        ],
      ],
    );
  }

  Widget _buildRow(
      BuildContext context, MoodleCourseGradeItem item, int index, int length) {
    final scheme = context.scheme;
    final borderRadius = UIUtils.getBorderRadius(index, length);
    return InkWell(
      borderRadius: borderRadius,
      onTap: () => unawaited(widget.onOpenCourse(item)),
      child: Container(
        decoration: BoxDecoration(
          color: context.tokens.card,
          borderRadius: borderRadius,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge
                        ?.copyWith(color: scheme.onSurface),
                  ),
                  Text(
                    item.courseId,
                    style: context.text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 伺服器格式化好的字串原樣顯示：它跟的是 Moodle 帳號語系，
            // 而且量尺與等第根本不是數字。
            Text(
              item.grade,
              style: AppTypography.tabular(
                context.text.titleSmall ?? const TextStyle(),
              ).copyWith(color: scheme.onSurface),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
