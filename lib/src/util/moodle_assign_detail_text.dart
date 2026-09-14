import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_submit_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_text.dart';
import 'package:sprintf/sprintf.dart';

typedef AssignNoteText = ({String text, bool blocking});

/// 作業詳情頁與繳交頁上的字：哪一句話在什麼時候出現。Flutter 的兩頁與原生版共用。
class MoodleAssignDetailText {
  MoodleAssignDetailText._();

  /// 成績、評分時間、回饋、回饋檔案四段全部落空時整個群組不畫，否則會多一張空卡。
  static bool hasFeedbackContent(MoodleAssignFeedback fb) =>
      fb.gradefordisplay.trim().isNotEmpty ||
      (fb.gradeddate ?? 0) > 0 ||
      fb.commentsHtml.trim().isNotEmpty ||
      fb.files.isNotEmpty;

  /// 「第 2 次繳交，共 3 次」；不限次數時少那半句。
  static String attemptLabel(AssignAttemptLabel label) => label.total > 0
      ? sprintf(R.current.assignAttemptLabelOf, [label.current, label.total])
      : sprintf(R.current.assignAttemptLabel, [label.current]);

  /// 先前的某一次：成績優先；還沒評過就講那一次交出去的時間。
  static String previousAttemptValue(MoodleAssignPreviousAttempt attempt) =>
      (attempt.grade?.hasDisplay ?? false)
          ? attempt.grade!.gradefordisplay
          : ((attempt.submission?.timemodified ?? 0) > 0
              ? assignFormatUnix(attempt.submission!.timemodified)
              : R.current.assignNotGraded);

  /// 團隊作業那一段的說明。組員名字拿不到也不去拿：WS 只給 id，而匿名評分的作業
  /// 去查名字就是把伺服器刻意藏起來的東西挖出來。
  static List<AssignNoteText> teamNotes(
      MoodleAssignment a, MoodleAssignSubmissionStatus s) {
    final state = MoodleAssignAttemptUtils.teamState(a, s);
    return [
      switch (state) {
        AssignTeamState.noGroup => (
            text: R.current.assignTeamNoGroup,
            blocking: true
          ),
        AssignTeamState.multipleGroups => (
            text: R.current.assignTeamMultipleGroups,
            blocking: true
          ),
        AssignTeamState.notTeam ||
        AssignTeamState.ok =>
          (text: R.current.assignTeamNotice, blocking: false),
      },
      // 全部交完時這個陣列是空的，照樣 sprintf 就會變成「還有 0 位組員
      // 尚未送出」——一句警告形狀的話貼在最好的那個狀態上。
      if (state == AssignTeamState.ok && a.requiresAllTeamMembersSubmit)
        (
          text: s.pendingGroupMembers.isEmpty
              ? R.current.assignTeamAllSubmitted
              : sprintf(R.current.assignTeamPendingMembers,
                  [s.pendingGroupMembers.length]),
          blocking: false
        ),
    ];
  }

  /// 繳交入口的字。標籤跟著 Moodle 網頁那張按鈕表走，不是自己看 submission 是不是 null。
  static String entryLabel(Set<AssignAction> actions) {
    if (actions.contains(AssignAction.addNewAttempt)) {
      return R.current.assignStartNewAttempt;
    }
    if (actions.contains(AssignAction.editSubmission)) {
      return R.current.assignEditSubmission;
    }
    return R.current.assignAddSubmission;
  }

  /// 不能在 App 內交的時候那一句。伺服器說不能交時入口根本不存在，也不對著沒權限的人喊話。
  static String? blockHint(AssignSubmitBlock block) => switch (block) {
        AssignSubmitBlock.unsupportedPlugin =>
          R.current.assignSubmitWebOnlyPlugin,
        AssignSubmitBlock.noGroup => R.current.assignTeamNoGroup,
        AssignSubmitBlock.multipleGroups => R.current.assignTeamMultipleGroups,
        AssignSubmitBlock.closed ||
        AssignSubmitBlock.noSubmission ||
        AssignSubmitBlock.noPlugin =>
          null,
      };

  /// 沒有草稿階段的作業，複製過來就是直接繳交，確認框要講清楚。
  static String copyConfirm(MoodleAssignment a) => a.tracksDrafts
      ? R.current.assignCopyPreviousConfirm
      : '${R.current.assignCopyPreviousConfirm}\n\n'
          '${R.current.assignCopyPreviousSubmitsNow}';

  /// 移除不可逆，所以確認框要一句一句講清楚會連帶發生什麼事。
  static String removeConfirm(AssignRemoveConsequences c) => [
        R.current.assignRemoveConfirm,
        if (c.wipesTeam) R.current.assignRemoveConfirmTeam,
        if (c.unsubmits) R.current.assignRemoveConfirmSubmitted,
        if (c.keepsTimer) R.current.assignRemoveKeepsTimer,
      ].join('\n\n');

  /// 繳交頁表頭底下那一句「按下儲存會發生什麼事」。原本這句話只活在按下去之後的
  /// 確認框裡，提前講出來才會把那個對話框從「告知」變成「確認」。
  static String consequence(
      MoodleAssignment a, MoodleAssignSubmissionStatus s) {
    final sub = s.submissionFor(a);
    if (sub != null && sub.isReopened) {
      // 重新開放**又**有草稿階段時兩件事都要講：只講「不影響上一次的成績」
      // 的話，最容易誤以為交完了的那一條路反而沒被告知還要按送出評分。
      return sprintf(
          a.tracksDrafts
              ? R.current.assignConsequenceReopenedDraft
              : R.current.assignConsequenceReopened,
          [MoodleAssignAttemptUtils.attemptLabel(a, s).current]);
    }
    if (a.tracksDrafts) return R.current.assignConsequenceDraft;
    if (sub != null && sub.isSubmitted) {
      return R.current.assignConsequenceOverwrite;
    }
    return R.current.assignConsequenceDirect;
  }

  /// 「按下開始後會有 30:00 的作答時間」。
  static String timeLimitNotice(
          MoodleAssignment a, MoodleAssignSubmissionStatus s) =>
      sprintf(R.current.assignTimeLimitNotice, [
        MoodleAssignAttemptUtils.formatDuration(
            MoodleAssignAttemptUtils.effectiveTimeLimit(a, s))
      ]);

  static String startConfirmation(
          MoodleAssignment a, MoodleAssignSubmissionStatus s) =>
      '${timeLimitNotice(a, s)}\n\n${R.current.assignStartConfirm}';

  /// 挑檔那一列的副標：三條限制併成一行寫在按鈕身上，犯錯之前就讀得到；滿了就說滿了。
  static String pickerHint(MoodleAssignment a, int count) {
    final maxFiles = MoodleAssignSubmitUtils.maxFiles(a);
    if (count >= maxFiles) {
      return sprintf(R.current.assignFileLimitReached, [maxFiles.toString()]);
    }
    final maxBytes = MoodleAssignSubmitUtils.maxBytes(a);
    final types = MoodleAssignSubmitUtils.fileTypes(a);
    return [
      sprintf(R.current.assignFileLimit, [maxFiles.toString()]),
      if (maxBytes > 0)
        sprintf(R.current.assignFileSizeLimit,
            [FileUtils.formatBytes(maxBytes, 1)]),
      if (types.isNotEmpty)
        sprintf(R.current.assignFileTypes, [types.join(', ')]),
    ].join(' · ');
  }

  /// 挑檔時可以交給挑選器過濾的副檔名。Moodle 的群組名（`document`、`archive`）
  /// 要整張 file types 表才解得開，清單裡有一個判讀不出來就整份不過濾，挑回來再擋。
  static List<String> pickerExtensions(List<String> types) {
    if (types.isEmpty) return const [];
    for (final t in types) {
      if (t.contains('/')) return const [];
      if (MoodleAssignSubmitUtils.checkFileType('probe.$t', types) ==
          FileTypeCheck.unverifiable) {
        return const [];
      }
    }
    return [for (final t in types) t.startsWith('.') ? t.substring(1) : t];
  }

  /// 儲存鈕為什麼不能按。超過字數上限而文字框又打不開時要換一句：叫使用者刪減他在
  /// App 裡根本碰不到的文字是句廢話。
  static String saveBlockMessage(AssignSaveBlock block,
          {required bool textEditable}) =>
      switch (block) {
        AssignSaveBlock.filesEmptied => R.current.assignFilesEmptiedWebOnly,
        AssignSaveBlock.overWordLimit => textEditable
            ? R.current.assignWordCountExceeded
            : R.current.assignWordCountExceededReadOnly,
        AssignSaveBlock.statementNotAccepted =>
          R.current.assignBlockedStatement,
        AssignSaveBlock.noChanges => R.current.assignBlockedNoChanges,
      };

  /// 前兩個是「這樣交出去會壞掉」，後兩個只是「還沒輪到」。
  static bool saveBlockIsError(AssignSaveBlock block) => switch (block) {
        AssignSaveBlock.filesEmptied || AssignSaveBlock.overWordLimit => true,
        AssignSaveBlock.statementNotAccepted ||
        AssignSaveBlock.noChanges =>
          false,
      };

  /// 儲存前的確認框內文；不需要問時回 null。
  ///
  /// 沒有草稿階段的作業「存檔」就是繳交、團隊作業會蓋掉整組的、時限過了會被標成
  /// 遲交、這一次會從 Moodle 刪掉已經交出去的檔案——這幾件事都得在按下去之前講。
  static String? saveConfirmation(
    MoodleAssignment a,
    MoodleAssignSubmissionStatus current, {
    required bool expired,
    required int removals,
  }) {
    if (a.tracksDrafts && !a.isTeamSubmission && !expired && removals == 0) {
      return null;
    }
    final already = current.submissionFor(a);
    return [
      a.tracksDrafts
          ? R.current.assignConsequenceDraft
          : R.current.assignSubmitDirectConfirm,
      if (removals > 0) sprintf(R.current.assignRemoveFilesWarning, [removals]),
      if (!a.tracksDrafts && (already?.isSubmitted ?? false))
        R.current.assignSubmitAgainWarning,
      if (a.isTeamSubmission) R.current.assignTeamOverwriteWarning,
      // 對話框裡講，但那顆鈕從頭到尾沒有被停用過：伺服器照收，只標記遲交。
      if (expired) R.current.assignTimeExpiredStillEditable,
    ].join('\n\n');
  }

  /// 傳輸列上那一句。整段下載都說「正在上傳」是騙人的。
  static String transferLabel(String? filename, AssignTransferPhase phase) =>
      filename == null
          ? R.current.assignSubmit
          : sprintf(
              phase == AssignTransferPhase.download
                  ? R.current.assignPreparingFile
                  : R.current.assignUploadingFile,
              [filename]);
}
