import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';

/// 作業清單上那一顆狀態籤。[noSubmissionRequired] 是離線評分的作業
/// （`nosubmissions == 1`），Moodle 自己也不說 overdue / no attempt。
enum AssignDisplayStatus {
  notSubmitted,
  draft,
  submitted,
  graded,
  overdue,

  /// 老師重開了一次，這一次是空的（`add_attempt` 建的那一列）。
  reopened,
  noSubmissionRequired,
}

/// 截止日期的相對時間提示。字串對映在 UI 層（要 R.current）。
enum DueHintKind {
  noDueDate,
  dueInDays,
  dueInHours,
  dueSoon,
  overdueDays,
  overdueHours,
  overdueJustNow,
}

typedef DueHint = ({DueHintKind kind, int count});

/// 作業狀態、截止日期與排序的純函式。不碰 R.current 也不碰時鐘，
/// `now` 一律由呼叫端傳進來。
class MoodleAssignUtils {
  MoodleAssignUtils._();

  /// 實際生效的截止時間（Unix 秒）：有延長期限就用延長期限，否則 duedate。
  /// 0 代表沒有截止。
  static int effectiveDueDate(
      MoodleAssignment a, MoodleAssignSubmissionStatus? s) {
    final ext = s?.extensionDueDate ?? 0;
    return ext > 0 ? ext : a.duedate;
  }

  static bool isOverdue(
      MoodleAssignment a, MoodleAssignSubmissionStatus? s, DateTime now) {
    final due = effectiveDueDate(a, s);
    return due > 0 && now.millisecondsSinceEpoch ~/ 1000 >= due;
  }

  /// 判定順序：已評分 > 不需繳交 > 已繳交 > 已逾期 > 草稿 > 重新開放 > 未繳交。
  /// 草稿過了截止算已逾期：草稿不會被評分，對學生來說等同沒交。
  /// 重新開放過了截止也一樣算逾期，跟草稿同一條規則。
  static AssignDisplayStatus resolveStatus(
    MoodleAssignment a,
    MoodleAssignSubmissionStatus s, {
    required DateTime now,
  }) {
    if (s.isGraded) return AssignDisplayStatus.graded;
    if (a.noSubmissionRequired) return AssignDisplayStatus.noSubmissionRequired;
    final sub = s.submissionFor(a);
    if (sub != null && sub.isSubmitted) return AssignDisplayStatus.submitted;
    if (isOverdue(a, s, now)) return AssignDisplayStatus.overdue;
    if (sub != null && sub.isDraft) return AssignDisplayStatus.draft;
    if (sub != null && sub.isReopened) return AssignDisplayStatus.reopened;
    return AssignDisplayStatus.notSubmitted;
  }

  /// 相對時間提示。[dueUnix] 是 Unix 秒；0 = 沒有截止日期。
  /// 剛好等於 now 時 diff 不是負的，落在 dueSoon。
  static DueHint dueHint(int dueUnix, DateTime now) {
    if (dueUnix <= 0) return (kind: DueHintKind.noDueDate, count: 0);
    final diff =
        DateTime.fromMillisecondsSinceEpoch(dueUnix * 1000).difference(now);
    if (diff.isNegative) {
      final past = -diff;
      if (past.inDays >= 1) {
        return (kind: DueHintKind.overdueDays, count: past.inDays);
      }
      if (past.inHours >= 1) {
        return (kind: DueHintKind.overdueHours, count: past.inHours);
      }
      return (kind: DueHintKind.overdueJustNow, count: 0);
    }
    if (diff.inDays >= 1) {
      return (kind: DueHintKind.dueInDays, count: diff.inDays);
    }
    if (diff.inHours >= 1) {
      return (kind: DueHintKind.dueInHours, count: diff.inHours);
    }
    return (kind: DueHintKind.dueSoon, count: 0);
  }

  /// 未截止的在前（升冪、沒有截止日排最後），已截止的在後（降冪）。
  /// 同鍵拿原 index 當次鍵，因為 `List.sort` 不穩定。不改動輸入。
  static List<MoodleAssignment> sortForList(
    List<MoodleAssignment> items,
    DateTime now, {
    int Function(MoodleAssignment a)? dueOf,
  }) {
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
    final due = dueOf ?? (a) => a.duedate;

    final indexed = [
      for (var i = 0; i < items.length; i++)
        (index: i, item: items[i], due: due(items[i])),
    ];
    bool isPast(int due) => due > 0 && due <= nowUnix;
    indexed.sort((x, y) {
      final px = isPast(x.due);
      final py = isPast(y.due);
      if (px != py) return px ? 1 : -1;
      if (px) {
        final c = y.due.compareTo(x.due);
        if (c != 0) return c;
      } else {
        final hx = x.due > 0;
        final hy = y.due > 0;
        if (hx != hy) return hx ? -1 : 1;
        if (hx) {
          final c = x.due.compareTo(y.due);
          if (c != 0) return c;
        }
      }
      return x.index.compareTo(y.index);
    });
    return [for (final e in indexed) e.item];
  }

  static MoodleAssignment? findById(List<MoodleAssignment> items, int id) {
    for (final a in items) {
      if (a.id == id) return a;
    }
    return null;
  }
}
