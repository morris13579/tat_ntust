import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/util/moodle_assign_utils.dart';
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

/// 作業狀態籤與清單列上的字。Flutter 的作業分頁、詳情頁與原生版共用。
class MoodleAssignText {
  MoodleAssignText._();

  /// 延長期限只有在還沒交、也還沒逾期的時候才是這一列的重點：交出去之後
  /// 期限是多久已經不重要，過了延長後的期限就變成逾期。
  static bool isExtended(
          AssignDisplayStatus status, MoodleAssignSubmissionStatus? data) =>
      status == AssignDisplayStatus.notSubmitted &&
      (data?.extensionDueDate ?? 0) > 0;

  static String statusLabel(AssignDisplayStatus status,
          {bool extended = false}) =>
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

  /// 清單頂上那一句「N 件 · 全部已評分」。
  ///
  /// 只有在每一份的狀態都抓到、而且真的每一份都評完時才敢說「全部已評分」：
  /// 少一份沒抓到就只報件數，寧可少說一句，也不要在還有作業沒交的時候
  /// 讓人以為都結了。
  static String listSummary(
      List<(MoodleAssignment, MoodleAssignSubmissionStatus?)> items,
      DateTime now) {
    final count = sprintf(R.current.assignCountItems, [items.length]);
    final allGraded = items.isNotEmpty &&
        items.every((e) {
          final data = e.$2;
          return data != null &&
              MoodleAssignUtils.resolveStatus(e.$1, data, now: now) ==
                  AssignDisplayStatus.graded;
        });
    return allGraded ? '$count · ${R.current.assignAllGraded}' : count;
  }

  /// 標題底下那一行。右邊那一格只放一顆籤或一個分數，所以「為什麼是這個狀態」
  /// 全部由這一行講完。
  ///
  /// 關鍵的一條：**逾期天數只在「未繳交且已過期」時出現**。交出去或評完之後，
  /// 那份作業遲不遲到已經不是使用者現在要處理的事，這一行改講繳交日或截止日；
  /// 繼續掛著「已逾期 5 天」會讓一份已經評完的作業看起來還欠著。
  static String rowSubtitle(MoodleAssignment a, MoodleAssignSubmissionStatus? data,
      AssignDisplayStatus? status, DateTime now) {
    final due = MoodleAssignUtils.effectiveDueDate(a, data);
    final submission = data?.submissionFor(a);
    final edited = submission?.timemodified ?? 0;

    switch (status) {
      case AssignDisplayStatus.graded:
        return "${_dueOrNone(due)} · ${R.current.assignStatusGraded}";
      // 不用交的作業過了截止也不是欠著，只說截止日。
      case AssignDisplayStatus.noSubmissionRequired:
        return _dueOrNone(due);
      case AssignDisplayStatus.submitted:
        if (edited > 0) {
          return sprintf(R.current.assignSubmittedOn, [_day(edited)]);
        }
      case AssignDisplayStatus.draft:
        // 草稿講的是「你上次寫到哪裡」，不是截止日：右邊那顆籤已經說了草稿。
        if (edited > 0) {
          return sprintf(R.current.assignDraftEditedAt, [_day(edited)]);
        }
      case AssignDisplayStatus.overdue:
        return dueRemainText(MoodleAssignUtils.dueHint(due, now));
      case null:
      case AssignDisplayStatus.notSubmitted:
      case AssignDisplayStatus.reopened:
        break;
    }

    if (due <= 0) return R.current.assignNoDueDate;
    final remain = dueRemainText(MoodleAssignUtils.dueHint(due, now));
    // 延長期限先講，不然「剩 4 天」跟作業上寫的截止日對不起來。
    if ((data?.extensionDueDate ?? 0) > 0) {
      return "${sprintf(R.current.assignExtendedTo, [
            _dateTime(due)
          ])} · $remain";
    }
    return "$remain · ${_dateTime(due)}";
  }

  static String _dueOrNone(int due) => due > 0
      ? sprintf(R.current.assignDueOn, [_date(due)])
      : R.current.assignNoDueDate;

  /// 「2025/6/4」。已經定案的那幾種（評完了、不用交）用年月日：那是一個
  /// 過去的事實，沒有必要精確到分。
  static String _date(int unix) =>
      DateFormat.yMd().format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));

  /// 「3月19日 23:59」。還沒到的期限要看到時分——差幾個小時交得出來與交不出來
  /// 是兩回事。
  static String _dateTime(int unix) => DateFormat.MMMd()
      .add_Hm()
      .format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));

  /// 「3月18日」。繳交與存草稿的那一天，時分不重要。
  static String _day(int unix) => DateFormat.MMMd()
      .format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));

  /// 「92 /100」。伺服器只給一整串 `gradefordisplay`，斜線前後的大小不一樣，
  /// 所以在斜線切一刀——切不到就整串照原樣。伺服器用不換行空格（\u00a0）當
  /// 分隔，兩種空白都要拿掉，「/100.00」才會緊貼在分數後面。
  static ({String big, String? small}) splitGrade(String grade) {
    final slash = grade.indexOf('/');
    if (slash < 0) return (big: grade, small: null);
    return (
      big: grade.substring(0, slash).trim(),
      small:
          grade.substring(slash).replaceAll('\u00a0', '').replaceAll(' ', ''),
    );
  }
}
