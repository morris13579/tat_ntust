import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart'
    show MoodleWebApiConnector;
import 'package:flutter_app/src/controller/course_data/course_data_controller.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/moodle_assign_text.dart';
import 'package:flutter_app/src/util/moodle_assign_utils.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/page/empty_state.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_assignment_detail_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/assign_status_chip.dart';
import 'package:get/get.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 課程頁的「作業」分頁：清單加上每一份作業的狀態籤。錯誤畫面與 WebView
/// 開啟器由呼叫端注入，見 docs/ARCHITECTURE.md「UI 慣例」。
class CourseAssignmentPage extends StatefulWidget {
  const CourseAssignmentPage(
    this.courseInfo, {
    required this.controller,
    required this.errorBuilder,
    required this.openWebView,
    super.key,
  });

  final CourseInfoJson courseInfo;

  /// 四個分頁共用的狀態；請求在進入頁面時已一次發完。
  final CourseDataController controller;

  final Widget Function(String message) errorBuilder;
  final WebViewOpener openWebView;

  @override
  State<CourseAssignmentPage> createState() => _CourseAssignmentPageState();
}

class _CourseAssignmentPageState extends State<CourseAssignmentPage>
    with AutomaticKeepAliveClientMixin {
  Rxn<Result<List<MoodleAssignment>>> get _state =>
      widget.controller.assignments;

  // 沒有 initState 觸發請求，見 CourseDataController.loadAll。

  Future<void> _load() => widget.controller.loadAssignments();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ResultView<List<MoodleAssignment>>(
      state: _state,
      onRetry: _load,
      errorBuilder: widget.errorBuilder,
      builder: buildTree,
    );
  }

  Widget buildTree(List<MoodleAssignment> list) {
    if (list.isEmpty) {
      return EmptyState(
        icon: LucideIconsThin.clipboardList,
        message: R.current.assignmentEmpty,
      );
    }

    // now 只取一次：排序、每一列的提示與狀態籤用同一個時間點。而且要跟詳情頁
    // 同一個時鐘——那邊的截止時間全是伺服器寫的，兩邊各用各的就會在同一份
    // 作業上一個說已逾期、一個說還沒。
    final now = MoodleWebApiConnector.serverNow();
    // 在 ResultView 的 Obx 之內，所以背景抓到狀態時清單會跟著重排。
    final items = MoodleAssignUtils.sortForList(
      list,
      now,
      dueOf: (a) => MoodleAssignUtils.effectiveDueDate(a, _statusDataOf(a)),
    );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      // 第 0 列是清單自己的一句話，其餘才是作業。
      itemCount: items.length + 1,
      itemBuilder: (context, index) => index == 0
          ? _summary(items, now)
          : _buildRow(items[index - 1], index - 1, items.length, now),
    );
  }

  /// 清單頂上那一句「N 件 · 全部已評分」。
  ///
  /// 只有在每一份的狀態都抓到、而且真的每一份都評完時才敢說「全部已評分」：
  /// 少一份沒抓到就只報件數，寧可少說一句，也不要在還有作業沒交的時候
  /// 讓人以為都結了。狀態是背景抓的，所以這一句自己訂閱一次。
  Widget _summary(List<MoodleAssignment> items, DateTime now) => Obx(() {
        final summary = MoodleAssignText.listSummary([
          for (final a in items)
            (a, widget.controller.statusOf(a.id).value?.dataOrNull),
        ], now);
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
          child: Text(
            summary,
            style: AppTypography.tabular(
                (context.text.bodySmall ?? const TextStyle())
                    .copyWith(color: context.scheme.onSurfaceVariant)),
          ),
        );
      });

  MoodleAssignSubmissionStatus? _statusDataOf(MoodleAssignment a) =>
      widget.controller.statusOf(a.id).value?.dataOrNull;

  /// 狀態決定圖示與它的顏色：逾期是 error、還沒交完是 warning、
  /// 交出去或評完了是中性與 success。整列的第一眼就是這一格。
  (IconData, Color) _statusIcon(AssignDisplayStatus? status) {
    final scheme = context.scheme;
    final tokens = context.tokens;
    return switch (status) {
      null => (LucideIcons.clipboardList, scheme.onSurfaceVariant),
      AssignDisplayStatus.overdue => (LucideIcons.circleAlert, scheme.error),
      // 草稿有文件圖示而不是驚嘆號：東西已經寫了，只是還沒送出去，
      // 跟「連碰都還沒碰」不是同一件事。
      AssignDisplayStatus.draft => (LucideIcons.fileText, tokens.warning),
      AssignDisplayStatus.notSubmitted || AssignDisplayStatus.reopened => (
          LucideIcons.circleAlert,
          tokens.warning
        ),
      AssignDisplayStatus.submitted => (
          LucideIcons.circleCheck,
          scheme.onSurfaceVariant
        ),
      AssignDisplayStatus.graded => (LucideIcons.circleCheck, tokens.success),
      AssignDisplayStatus.noSubmissionRequired => (
          LucideIcons.circleCheck,
          scheme.onSurfaceVariant
        ),
    };
  }

  Widget _buildRow(MoodleAssignment a, int index, int length, DateTime now) {
    final scheme = context.scheme;
    final text = context.text;
    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : 2),
      child: Material(
        color: context.tokens.card,
        borderRadius: UIUtils.getBorderRadius(index, length),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(Get.to(() => CourseAssignmentDetailPage(
                widget.courseInfo,
                assignId: a.id,
                assignment: a,
                initialStatus: widget.controller.statusOf(a.id).value,
                errorBuilder: widget.errorBuilder,
                openWebView: widget.openWebView,
                // 詳情頁交完之後，這一列的狀態籤要跟著換。
                onStatusChanged: (s) =>
                    widget.controller.statusOf(a.id).value = Ok(s),
              ))),
          // itemBuilder 在 layout 階段跑，不在外層 Obx 的追蹤範圍內，所以
          // 這一列自己訂閱一次：背景抓回狀態時圖示、說明與分數要一起換。
          child: Obx(() {
            final result = widget.controller.statusOf(a.id).value;
            final data = result?.dataOrNull;
            final status = data == null
                ? null
                : MoodleAssignUtils.resolveStatus(a, data, now: now);
            final (icon, iconColor) = _statusIcon(status);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium
                              ?.copyWith(color: scheme.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          MoodleAssignText.rowSubtitle(a, data, status, now),
                          style: AppTypography.tabular(
                              (text.bodySmall ?? const TextStyle()).copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.45)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _trailing(a, result, status, now),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  /// 已評分就印分數，其餘印狀態籤。快取（[Stale]）一律留在籤上：那顆籤才有
  /// 「這是舊資料」的記號，一個裸分數說不出自己是什麼時候的。
  Widget _trailing(MoodleAssignment a, Result<MoodleAssignSubmissionStatus>? r,
      AssignDisplayStatus? status, DateTime now) {
    if (r is Ok<MoodleAssignSubmissionStatus> &&
        status == AssignDisplayStatus.graded) {
      final grade = r.data.feedback?.gradefordisplay.trim() ?? "";
      if (grade.isNotEmpty) return _GradeText(grade: grade);
    }
    return AssignStatusChip.fromResult(a, r, now: now);
  }

  @override
  bool get wantKeepAlive => true;
}

/// 「92 /100」。伺服器只給一整串 `gradefordisplay`，斜線前後的大小不一樣，
/// 所以在斜線切一刀——切不到就整串照原樣印。
class _GradeText extends StatelessWidget {
  const _GradeText({required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    final big = AppTypography.tabular(text.titleLarge!.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ));
    final small = AppTypography.tabular((text.bodySmall ?? const TextStyle())
        .copyWith(color: scheme.onSurfaceVariant));
    final split = MoodleAssignText.splitGrade(grade);
    final suffix = split.small;
    if (suffix == null) return Text(split.big, style: big);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(split.big, style: big),
        const SizedBox(width: 3),
        Text(suffix, style: small),
      ],
    );
  }
}
