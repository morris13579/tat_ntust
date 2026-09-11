import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/moodle_assign_utils.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/status_pill.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';

/// Unix 秒 → 畫面上的日期時間。作業詳情頁、繳交頁的表頭與清單共用同一種
/// 格式，放在這裡是因為頁面之間不互相 import（見 docs/ARCHITECTURE.md）。
String assignFormatUnix(int unix) => DateFormat.yMd()
    .add_jm()
    .format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));

/// 同一個 [DueHint]，但講的是「還剩多久」而不是「什麼時候截止」。
///
/// 清單那一列右邊已經有籤或分數，左下那一行的空間只夠講一件事，所以講剩餘
/// 時間；詳情頁的欄位標題就是「截止日期」，那裡才需要 [dueHintText] 的說法。
/// 已逾期的幾種共用同一組字：過期之後「剩多久」沒有意義。
String dueRemainText(DueHint hint) => switch (hint.kind) {
      DueHintKind.dueInDays =>
        sprintf(R.current.assignRemainDays, [hint.count]),
      DueHintKind.dueInHours =>
        sprintf(R.current.assignRemainHours, [hint.count]),
      DueHintKind.dueSoon => R.current.assignRemainSoon,
      _ => dueHintText(hint),
    };

/// [DueHint] 對映成畫面文字。住在 UI 層是因為要 R.current；
/// 作業分頁與詳情頁共用。
String dueHintText(DueHint hint) => switch (hint.kind) {
      DueHintKind.noDueDate => R.current.assignNoDueDate,
      DueHintKind.dueInDays => sprintf(R.current.assignDueInDays, [hint.count]),
      DueHintKind.dueInHours =>
        sprintf(R.current.assignDueInHours, [hint.count]),
      DueHintKind.dueSoon => R.current.assignDueSoon,
      DueHintKind.overdueDays =>
        sprintf(R.current.assignOverdueDays, [hint.count]),
      DueHintKind.overdueHours =>
        sprintf(R.current.assignOverdueHours, [hint.count]),
      DueHintKind.overdueJustNow => R.current.assignOverdueJustNow,
    };

/// 作業的狀態籤，作業分頁與詳情頁共用；外觀走共用的 [StatusPill]，
/// 刻意不 import 任何頁面。
class AssignStatusChip extends StatelessWidget {
  const AssignStatusChip(this.status,
      {super.key, this.stale = false, this.extended = false});

  final AssignDisplayStatus status;

  /// 資料來自快取（[Stale]）時多畫一個時鐘小圖示。
  final bool stale;

  /// 老師給了這位學生延長期限，而作業還沒交出去、也還沒到延長後的期限。
  /// 狀態本身仍然是「未繳交」，但籤要說「已延長」：旁邊那一行說的是延長到
  /// 哪一天，籤卻只說未繳交的話，兩句話對不起來。
  final bool extended;

  /// null 還在抓畫轉圈；[Failed] 不知道狀態就什麼都不畫（背景抓的，不彈框）。
  static Widget fromResult(
    MoodleAssignment a,
    Result<MoodleAssignSubmissionStatus>? r, {
    required DateTime now,
  }) {
    if (r == null) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final data = r.dataOrNull;
    if (data == null) return const SizedBox.shrink();
    final status = MoodleAssignUtils.resolveStatus(a, data, now: now);
    return AssignStatusChip(
      status,
      stale: r is Stale,
      extended: isExtended(status, data),
    );
  }

  /// 延長期限只有在還沒交、也還沒逾期的時候才是這一列的重點：交出去之後
  /// 期限是多久已經不重要，過了延長後的期限就變成逾期。
  static bool isExtended(
          AssignDisplayStatus status, MoodleAssignSubmissionStatus? data) =>
      status == AssignDisplayStatus.notSubmitted &&
      (data?.extensionDueDate ?? 0) > 0;

  static String labelOf(AssignDisplayStatus status, {bool extended = false}) =>
      switch (status) {
        AssignDisplayStatus.notSubmitted => extended
            ? R.current.assignStatusExtended
            : R.current.assignStatusNotSubmitted,
        AssignDisplayStatus.draft => R.current.assignStatusDraft,
        // 「已繳交」講的是學生做完的事，這一顆籤要講的是接下來會發生什麼：
        // 交出去之後在等老師評分。
        AssignDisplayStatus.submitted => R.current.assignStatusAwaitingGrade,
        AssignDisplayStatus.graded => R.current.assignStatusGraded,
        AssignDisplayStatus.overdue => R.current.assignStatusOverdue,
        AssignDisplayStatus.reopened => R.current.assignStatusReopened,
        AssignDisplayStatus.noSubmissionRequired =>
          R.current.assignStatusNoSubmissionRequired,
      };

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      // 未繳交、已延長、草稿、重新開放是同一件事的四種說法：還沒交出去，
      // 而時間在走。設計稿上它們共用同一組提醒色。
      AssignDisplayStatus.notSubmitted ||
      AssignDisplayStatus.draft ||
      AssignDisplayStatus.reopened =>
        StatusPillTone.attention,
      // 交出去了、或本來就不用交：球不在學生手上，中性色。
      AssignDisplayStatus.submitted ||
      AssignDisplayStatus.noSubmissionRequired =>
        StatusPillTone.pending,
      AssignDisplayStatus.graded => StatusPillTone.graded,
      AssignDisplayStatus.overdue => StatusPillTone.overdue,
    };
    return StatusPill(
      tone: tone,
      stale: stale,
      label: labelOf(status, extended: extended),
    );
  }
}
