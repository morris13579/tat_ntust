import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';

/// 詳情頁與繳交頁上可能出現的動作。這一份枚舉就是 Moodle 網頁
/// `mod/assign/classes/output/user_submission_actionmenu.php` 的按鈕表，
/// 兩邊的規則只有一套實作。
enum AssignAction {
  /// 有作答時限而且還沒開始：要先 `mod_assign_start_submission`。
  /// **只有繳交頁的動作列會畫它**，詳情頁不畫（倒數要在按下去的那一頁看得到）。
  beginTimed,

  addSubmission,
  editSubmission,

  /// 老師重開了一次（status == reopened），這一次是空的。
  addNewAttempt,

  /// 把上一次的內容複製進這一次（`mod_assign_copy_previous_attempt`）。
  copyPrevious,

  /// 移除這一次的繳交（`mod_assign_remove_submission`）。
  removeSubmission,

  submitForGrading,
}

/// 作答時限現在的狀態。[none] = 這份作業根本沒有時限。
enum AssignTimerState {
  none,
  notStarted,
  running,
  expired,

  /// 伺服器已經開始計時，但那一趟寫入之後狀態重抓失敗，算不出還剩多久。
  /// 不可以退回 [notStarted]：那會把使用者鎖在一顆再按也沒有結果的鈕上。
  startedUnknown,
}

/// 「開始作答」那一趟寫入回報的事實。這兩件事沒有任何狀態欄位講得出來，
/// 只有那一則 warning 講得出來，所以由呼叫端帶進 [MoodleAssignAttemptUtils.timerState]。
///
/// 刻意在這裡重新宣告而不是直接用 connector 的 `AssignStartOutcome`：
/// util → connector 是上行邊。
enum AssignStartFact {
  /// `timelimitnotenabled`：站台層級的 `enabletimelimit` 是關的，`timelimit`
  /// 欄位還在但不會生效。沒有這一則線索就會永遠停在 [AssignTimerState.notStarted]。
  noTimeLimit,

  /// 伺服器真的開始計時了（`started` 或 `opensubmissionexists`）。
  started,
}

/// 這份作業是不是團隊作業，以及伺服器算不算得出要交給哪一組。
/// [noGroup] 與 [multipleGroups] 都是老師才修得好的設定，不是 App 的錯。
enum AssignTeamState { notTeam, noGroup, multipleGroups, ok }

/// 站台對這個 token 開放了哪幾支寫入 function。由 connector 的
/// `wsFunctionBlocked` 決定，傳進來而不是在這裡問——這個檔案不 import connector。
typedef AssignAvailability = ({bool canRemove, bool canStart, bool canCopy});

/// 一次繳交是第幾次。[total] 為 -1 代表不限次數，畫面要少畫「共 M 次」那半。
typedef AssignAttemptLabel = ({int current, int total});

/// 移除這一次繳交會連帶發生什麼事，用來組確認框的句子。
typedef AssignRemoveConsequences = ({
  bool wipesTeam,
  bool unsubmits,
  bool keepsTimer,
});

/// 次數、作答時限、團隊與移除／複製的純函式。不 import connector、
/// 不碰 R.current、不碰時鐘（`now` 一律由呼叫端傳進來），同
/// [MoodleAssignUtils] 對自己立的規矩。
class MoodleAssignAttemptUtils {
  MoodleAssignAttemptUtils._();

  /// 現在畫得出來的動作。這是
  /// `user_submission_actionmenu::export_for_template` 的移植：
  ///
  /// - `canedit` 就是網頁的 `$showedit`，沒有它一顆編輯類的鈕都不該出現；
  /// - `cansubmit` 是另一條獨立的閘門（`show_submit_button`），
  ///   所以「送出評分」不受 `canedit` 影響；
  /// - `new` / `reopened` 沒有東西可以移除，網頁也不畫那一項。
  static Set<AssignAction> actionsFor(
    MoodleAssignment a,
    MoodleAssignSubmissionStatus s, {
    required AssignAvailability api,
  }) {
    final out = <AssignAction>{};
    if (s.canEdit) {
      final sub = s.submissionFor(a);
      final status = sub?.status ?? MoodleAssignSubmission.statusNew;
      switch (status) {
        // 連一筆繳交都還沒有時伺服器不送 submission，等同 new。
        case MoodleAssignSubmission.statusNew:
          out.add(AssignAction.addSubmission);
          // 計時是另一顆鈕、另一趟寫入，跟「進去編輯」並存：詳情頁畫進入口，
          // 繳交頁的動作列才畫「開始作答」。
          if (api.canStart &&
              timerState(a, s, null) == AssignTimerState.notStarted) {
            out.add(AssignAction.beginTimed);
          }
        case MoodleAssignSubmission.statusReopened:
          out.add(AssignAction.addNewAttempt);
          if (api.canCopy) out.add(AssignAction.copyPrevious);
        // draft / submitted，以及任何我們不認得的狀態。
        default:
          out.add(AssignAction.editSubmission);
          if (api.canRemove) out.add(AssignAction.removeSubmission);
      }
    }
    if (s.canSubmit) out.add(AssignAction.submitForGrading);
    return out;
  }

  /// 真正該拿來倒數的作答時限（秒）。`lastattempt.timelimit` 優先：
  /// `get_assignments` 的那一欄是原始欄位值，沒有套使用者／群組 override。
  static int effectiveTimeLimit(
      MoodleAssignment a, MoodleAssignSubmissionStatus s) {
    final fromStatus = s.timeLimit;
    return fromStatus > 0 ? fromStatus : a.timelimit;
  }

  /// 作答時限現在的狀態。[now] 傳 null 時只回答「有沒有時限、開始了沒有」，
  /// 不判斷有沒有過期——[actionsFor] 就是這樣用的，它不該需要時鐘。
  ///
  /// [startFact] 是「開始作答」那一趟寫入回報的事實，優先於狀態欄位算出來的
  /// 結論：站台關掉時限、或是伺服器開始了但狀態重抓失敗，兩者的欄位長得跟
  /// 「還沒開始」一模一樣。
  static AssignTimerState timerState(
      MoodleAssignment a, MoodleAssignSubmissionStatus s, DateTime? now,
      {AssignStartFact? startFact}) {
    if (startFact == AssignStartFact.noTimeLimit) return AssignTimerState.none;
    if (effectiveTimeLimit(a, s) <= 0) return AssignTimerState.none;
    if (s.timeStarted(a) <= 0) {
      return startFact == AssignStartFact.started
          ? AssignTimerState.startedUnknown
          : AssignTimerState.notStarted;
    }
    if (now == null) return AssignTimerState.running;
    return now.millisecondsSinceEpoch ~/ 1000 >= timerEndUnix(a, s)
        ? AssignTimerState.expired
        : AssignTimerState.running;
  }

  /// 倒數的終點（Unix 秒）。照抄 `timelimit_panel::end_time()`：
  /// 先算 `timestarted + timelimit`，有 duedate 就跟它取小，否則跟 cutoffdate
  /// 取小。這裡刻意用 `a.duedate` 而不是套過延長期限的那個——延長期限是
  /// user flag，不在 `update_effective_access` 改寫的四個欄位裡，網頁也沒用它。
  static int timerEndUnix(MoodleAssignment a, MoodleAssignSubmissionStatus s) {
    final end = s.timeStarted(a) + effectiveTimeLimit(a, s);
    if (a.duedate > 0) return end < a.duedate ? end : a.duedate;
    if (a.cutoffdate > 0) return end < a.cutoffdate ? end : a.cutoffdate;
    return end;
  }

  /// 還剩幾秒；已經過了回 0。
  static int timeLeftSeconds(
      MoodleAssignment a, MoodleAssignSubmissionStatus s, DateTime now) {
    final left = timerEndUnix(a, s) - now.millisecondsSinceEpoch ~/ 1000;
    return left > 0 ? left : 0;
  }

  /// 秒數 → 顯示字串。超過一小時是 `H:MM:SS`，否則 `MM:SS`。
  /// 刻意只用數字不帶單位：時／分／秒的單位詞每種語言都得各寫一句，而
  /// 這個格式跟 Moodle 網頁的 timer.js（`00:00:00`）本來就是同一套。
  static String formatDuration(int seconds) {
    final total = seconds > 0 ? seconds : 0;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final sec = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// 第幾次 / 共幾次。`attemptnumber` 是 0 起算的，畫面要 1 起算。
  static AssignAttemptLabel attemptLabel(
          MoodleAssignment a, MoodleAssignSubmissionStatus s) =>
      (current: s.attemptNumber(a) + 1, total: a.maxattempts);

  static AssignTeamState teamState(
      MoodleAssignment a, MoodleAssignSubmissionStatus s) {
    if (!a.isTeamSubmission) return AssignTeamState.notTeam;
    // 伺服器算得出組別就沒有什麼好說的，先問它。
    if (s.hasSubmissionGroup) return AssignTeamState.ok;
    // `preventsubmissionnotingroup` 關著（Moodle 的預設）時，沒分到組與跨多組
    // 的人照樣交得出去，伺服器會收進預設組別——`can_edit_submission` 只在這個
    // 開關為真時才擋。少了這一行就會對著一個沒有在擋人的設定喊「請聯絡老師」。
    if (!a.preventsSubmissionNotInGroup) return AssignTeamState.ok;
    if (s.groupCount == 0) return AssignTeamState.noGroup;
    if (s.groupCount >= 2) return AssignTeamState.multipleGroups;
    return AssignTeamState.ok;
  }

  /// 移除這一次繳交會連帶發生什麼事。
  ///
  /// - [wipesTeam]：`assign::remove_submission` 動的是群組那一筆，而
  ///   `update_team_submission` 會把重設後的狀態寫回每一位組員的列。
  /// - [unsubmits]：已經是 submitted 的那一次會被退回 new/reopened 並清空。
  /// - [keepsTimer]：`timestarted` 不會被清掉（網頁的
  ///   `removesubmissionconfirmwithtimelimit` 講的就是這件事）。
  static AssignRemoveConsequences removeConsequences(
      MoodleAssignment a, MoodleAssignSubmissionStatus s) {
    final sub = s.submissionFor(a);
    return (
      wipesTeam: a.isTeamSubmission,
      unsubmits: sub?.isSubmitted ?? false,
      keepsTimer: effectiveTimeLimit(a, s) > 0 && s.timeStarted(a) > 0,
    );
  }
}
