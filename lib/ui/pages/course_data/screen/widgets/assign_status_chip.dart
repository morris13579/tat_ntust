import 'package:flutter/material.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/moodle_assign_text.dart';
import 'package:flutter_app/src/util/moodle_assign_utils.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/status_pill.dart';

export 'package:flutter_app/src/util/moodle_assign_text.dart'
    show assignFormatUnix, dueHintText, dueRemainText;

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
      MoodleAssignText.isExtended(status, data);

  static String labelOf(AssignDisplayStatus status, {bool extended = false}) =>
      MoodleAssignText.statusLabel(status, extended: extended);

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
