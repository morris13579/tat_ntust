import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_utils.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/assign_status_chip.dart';
import 'package:sprintf/sprintf.dart';

/// 繳交頁最上面那一條，永遠不捲動：截止提示、狀態籤，以及倒數、團隊、次數
/// 與「按下去會發生什麼事」。
///
/// 底色是裸的 `surface` 而不是 `surfaceContainer`——這一頁的卡片都是
/// `surfaceContainer`（見 `section_card.dart`），在這裡再放一張卡就會被讀成
/// 第四塊內容。滿版加一條 hairline 才讀得出來是機殼，同 `result_view.dart`
/// 的舊資料橫幅。
///
/// 值全部由呼叫端傳進來，`now` 也是：倒數的 ticker 住在頁面的 State，
/// 這個 widget 不碰時鐘，也刻意不 import 任何頁面。
class AssignSubmitStatusHeader extends StatelessWidget {
  const AssignSubmitStatusHeader({
    super.key,
    required this.assignment,
    required this.status,
    required this.now,
    this.startFact,
    this.compact = false,
  });

  final MoodleAssignment assignment;
  final MoodleAssignSubmissionStatus status;
  final DateTime now;

  /// 「開始作答」那一趟寫入回報的事實。狀態欄位講不出「站台關掉時限」與
  /// 「伺服器開始了但重抓失敗」，少了它這一條會畫成「還沒開始」。
  final AssignStartFact? startFact;

  /// 鍵盤升起時只留最上面那一行（截止提示、狀態籤與還在跑的倒數）。這一條
  /// 不捲動又沒有高度上限，六個區塊全開時在 360x640 上會把編輯區壓到零。
  final bool compact;

  /// Zone A 底下那一句「按下儲存會發生什麼事」。原本這句話只活在按下去之後
  /// 的確認框裡，提前講出來才會把那個對話框從「告知」變成「確認」。
  String _consequence(MoodleAssignSubmission? sub) {
    if (sub != null && sub.isReopened) {
      // 重新開放**又**有草稿階段時兩件事都要講：只講「不影響上一次的成績」
      // 的話，最容易誤以為交完了的那一條路反而沒被告知還要按送出評分。
      return sprintf(
          assignment.tracksDrafts
              ? R.current.assignConsequenceReopenedDraft
              : R.current.assignConsequenceReopened,
          [MoodleAssignAttemptUtils.attemptLabel(assignment, status).current]);
    }
    if (assignment.tracksDrafts) return R.current.assignConsequenceDraft;
    if (sub != null && sub.isSubmitted) {
      return R.current.assignConsequenceOverwrite;
    }
    return R.current.assignConsequenceDirect;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sub = status.submissionFor(assignment);
    final due = MoodleAssignUtils.effectiveDueDate(assignment, status);
    // 染紅的條件與那顆籤同源，照抄詳情頁的 _deadlineCard，否則會出現
    // 「已評分」卻紅字說已逾期。
    final alarm =
        MoodleAssignUtils.resolveStatus(assignment, status, now: now) ==
            AssignDisplayStatus.overdue;
    final ext = status.extensionDueDate;

    final state = MoodleAssignAttemptUtils.timerState(assignment, status, now,
        startFact: startFact);
    final timer = _timerRow(context, state);
    final team = compact ? null : _teamRow(context);
    final attempt = compact ? null : _attemptRow(context);

    final rows = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              dueHintText(MoodleAssignUtils.dueHint(due, now)),
              style: text.titleMedium?.copyWith(
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: alarm
                    ? scheme.error
                    : (assignment.hasDueDate
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AssignStatusChip(
              MoodleAssignUtils.resolveStatus(assignment, status, now: now)),
        ],
      ),
      if (!compact && assignment.hasDueDate)
        _spaced(
            4,
            Text(
              ext > 0
                  ? '${R.current.assignExtensionDueDate}：${_formatUnix(due)}'
                  : _formatUnix(due),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            )),
      if (timer != null) timer,
      if (team != null) team,
      if (attempt != null) attempt,
      if (!compact)
        _spaced(
            8,
            Text(_consequence(sub),
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: scheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
      ],
    );
  }

  static Widget _spaced(double gap, Widget child) => Padding(
        padding: EdgeInsets.only(top: gap),
        child: child,
      );

  /// 倒數那一行。running 時的那個數字是這一整條之所以要釘住不捲的理由，
  /// 所以 [compact] 時只有它留下來。
  Widget? _timerRow(BuildContext context, AssignTimerState state) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (state == AssignTimerState.none) return null;
    if (compact && state != AssignTimerState.running) return null;

    final (String label, TextStyle? style, Color color) = switch (state) {
      AssignTimerState.notStarted => (
          sprintf(R.current.assignTimeLimitNotice, [
            MoodleAssignAttemptUtils.formatDuration(
                MoodleAssignAttemptUtils.effectiveTimeLimit(assignment, status))
          ]),
          text.bodySmall,
          scheme.onSurfaceVariant
        ),
      AssignTimerState.running => (
          sprintf(R.current.assignTimeLeft, [
            MoodleAssignAttemptUtils.formatDuration(
                MoodleAssignAttemptUtils.timeLeftSeconds(
                    assignment, status, now))
          ]),
          text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          // 最後五分鐘才染紅：更早就紅的話，紅色在這一頁上就不再是訊號。
          MoodleAssignAttemptUtils.timeLeftSeconds(assignment, status, now) <
                  5 * 60
              ? scheme.error
              : scheme.onSurface
        ),
      // 伺服器已經開始計時，只是算不出還剩多久。退回「還沒開始」會把使用者
      // 鎖在一顆再按也沒有結果的鈕上，所以這裡照實說。
      AssignTimerState.startedUnknown => (
          R.current.assignTimerStartedUnknown,
          text.bodySmall,
          scheme.error
        ),
      // 時間到不會鎖住任何東西，伺服器照收只標記遲交。
      AssignTimerState.expired => (
          R.current.assignTimeExpiredStillEditable,
          text.bodySmall,
          scheme.error
        ),
      AssignTimerState.none => ('', text.bodySmall, scheme.onSurfaceVariant),
    };

    return _spaced(
      6,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.timer, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: style?.copyWith(color: color))),
        ],
      ),
    );
  }

  /// 共用的繳交會改變底下每一個控制項的意思，所以它屬於這一條，不是某一張卡。
  Widget? _teamRow(BuildContext context) {
    if (!assignment.isTeamSubmission) return null;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _spaced(
      6,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.users, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(R.current.assignTeamNotice,
                style:
                    text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  /// 第幾次。只在不是第一次時出現，而且是文字不是第二顆籤——一列兩顆籤就
  /// 不再掃得動了。
  Widget? _attemptRow(BuildContext context) {
    final label = MoodleAssignAttemptUtils.attemptLabel(assignment, status);
    if (label.current <= 1) return null;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _spaced(
      4,
      Text(
        label.total > 0
            ? sprintf(
                R.current.assignAttemptLabelOf, [label.current, label.total])
            : sprintf(R.current.assignAttemptLabel, [label.current]),
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  /// 詳情頁的 `CourseAssignmentDetailPage.formatUnix` 同一套格式，但這裡不
  /// import 那一頁（頁面之間不互相 import，見 docs/ARCHITECTURE.md）。
  static String _formatUnix(int unix) => assignFormatUnix(unix);
}
