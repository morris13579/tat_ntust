import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/course_data/course_assign_submit_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/native/bridge_results.dart';
import 'package:flutter_app/src/native/course_moodle_bridge.dart';
import 'package:flutter_app/src/native/moodle_memo.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/file_icon_utils.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_detail_text.dart';
import 'package:flutter_app/src/util/moodle_assign_submit_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_text.dart';
import 'package:flutter_app/src/util/moodle_assign_utils.dart';
import 'package:sprintf/sprintf.dart';

/// 原生版的作業詳情與繳交。規則照 `CourseAssignmentController`、
/// `CourseAssignSubmitController` 與兩頁上的判斷；繳交頁的草稿住在這裡，
/// Swift 每一次操作都拿回整份畫面。
class AssignmentBridge implements TatAssignmentApi {
  AssignmentBridge(
    this._memo, {
    DateTime Function()? now,
    void Function(TransferProgress progress)? onProgress,
  })  : _now = now ?? MoodleWebApiConnector.serverNow,
        _onProgress = onProgress ?? TatTransferHost().onProgress;

  static void install(MoodleMemo memo) =>
      TatAssignmentApi.setUp(AssignmentBridge(memo));

  final MoodleMemo _memo;
  final DateTime Function() _now;
  final void Function(TransferProgress progress) _onProgress;
  final Map<int, _Detail> _details = {};
  final Map<int, _Submit> _submits = {};

  @override
  Future<AssignmentDetailResult> detail(
      String courseId, int assignId, bool refresh) async {
    final entry = _details.putIfAbsent(assignId, () => _Detail(courseId));
    final listed = refresh
        ? null
        : MoodleAssignUtils.findById(
            _memo.assignments[courseId] ?? const [], assignId);
    final seeded = refresh ? null : _memo.statuses[assignId];
    final assignment = listed != null
        ? Future.value(Ok<MoodleAssignment>(listed))
        : MoodleRepository.instance.getAssignment(courseId, assignId);
    // Failed 的狀態要重抓：清單是背景抓的，這次是使用者主動要看。
    final status = seeded != null && seeded.hasData
        ? Future.value(seeded)
        : MoodleRepository.instance.getSubmissionStatus(assignId);
    entry.assignment = await assignment;
    _remember(assignId, await status);
    return _result(assignId);
  }

  @override
  Future<AssignWriteResult> submitForGrading(
      int assignId, bool acceptStatement) async {
    final (a, s) = _fresh(assignId);
    if (a == null || s == null) {
      return AssignWriteResult(
          messages: [R.current.assignSubmitForGradingRejected]);
    }
    return _afterWrite(
      assignId,
      await MoodleRepository.instance.submitAssignForGrading(
          assignment: a, status: s, acceptStatement: acceptStatement),
      success: R.current.assignSubmittedToast,
    );
  }

  @override
  Future<AssignWriteResult> removeSubmission(int assignId) async {
    final (a, s) = _fresh(assignId);
    if (a == null || s == null) {
      return AssignWriteResult(messages: [R.current.assignRemoveRejected]);
    }
    return _afterWrite(
      assignId,
      await MoodleRepository.instance
          .removeAssignSubmission(assignment: a, status: s),
      success: R.current.assignRemoved,
    );
  }

  @override
  Future<AssignWriteResult> copyPrevious(int assignId) async {
    final (a, s) = _fresh(assignId);
    if (a == null || s == null) {
      return AssignWriteResult(
          messages: [R.current.assignCopyPreviousRejected]);
    }
    return _afterWrite(
      assignId,
      await MoodleRepository.instance
          .copyPreviousAssignAttempt(assignment: a, status: s),
      success: R.current.assignCopyPreviousDone,
    );
  }

  @override
  Future<WebLink?> webLink(int assignId) async {
    final a = _details[assignId]?.assignment?.dataOrNull;
    if (a == null) return null;
    return CourseMoodleBridge.webLinkOf(CourseMoodleBridge.withLang(
        MoodleWebApiConnector.assignViewUrl(a.cmid)));
  }

  @override
  SubmitState? openSubmit(int assignId) {
    final entry = _details[assignId];
    final a = entry?.assignment;
    final s = entry?.status;
    // `submissiondrafts` 與 `configs` 是後來才新增的欄位，舊快取解出來全是預設值，
    // 拿它當寫入依據會直接把草稿交出去：兩個都要是這一趟抓到的。
    if (entry == null ||
        a is! Ok<MoodleAssignment> ||
        s is! Ok<MoodleAssignSubmissionStatus>) {
      return null;
    }
    _submits.remove(assignId)?.controller.dispose();
    final session = _Submit(
        CourseAssignSubmitController(assignment: a.data, status: s.data));
    _submits[assignId] = session;
    unawaited(session.controller.loadEditableText());
    return _state(session);
  }

  @override
  SubmitState setText(int assignId, String text) {
    final session = _submits[assignId]!;
    session.controller.onlineText.value = text;
    return _state(session);
  }

  @override
  SubmitState setAccepted(int assignId, bool accepted) {
    final session = _submits[assignId]!;
    session.controller.accepted.value = accepted;
    return _state(session);
  }

  @override
  Future<SubmitState> addFiles(int assignId, List<String> paths) async {
    final session = _submits[assignId]!;
    session.messages.addAll(await session.controller
        .addPicked([for (final path in paths) File(path)]));
    return _state(session);
  }

  @override
  SubmitState toggleFile(int assignId, int index) {
    final session = _submits[assignId]!;
    final c = session.controller;
    final drafts = c.serverDrafts;
    if (index < drafts.length) {
      final file = drafts[index];
      c.files.contains(file)
          ? c.removeServerFile(file)
          : c.restoreServerFile(file);
    } else {
      final local = c.files.whereType<LocalDraftFile>().toList();
      final at = index - drafts.length;
      if (at < local.length) c.files.remove(local[at]);
    }
    return _state(session);
  }

  @override
  String? saveConfirmation(int assignId) {
    final c = _submits[assignId]!.controller;
    return MoodleAssignDetailText.saveConfirmation(
      c.assignment,
      c.currentStatus,
      expired: _timerState(c) == AssignTimerState.expired,
      removals: c.pendingServerRemovals,
    );
  }

  @override
  Future<SubmitOutcome> save(int assignId) async {
    final session = _submits[assignId]!;
    final c = session.controller;
    final subscriptions = [
      c.progress.listen((_) => _report(assignId, c)),
      c.transferFile.listen((_) => _report(assignId, c)),
    ];
    _report(assignId, c);
    final AssignSaveOutcome outcome;
    try {
      outcome = await c.save(submitForGrading: false);
    } finally {
      // 串流關掉之後再退訂 GetX 會拋，所以要趕在 _closeWith 收掉 controller 之前。
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }
    // 這一次連請求都沒發（已經有一趟在跑），不可以報成功。
    if (!outcome.acted) {
      return SubmitOutcome(messages: [], close: false, state: _state(session));
    }
    final result = c.lastResult;
    final error = outcome.error;
    final messages = [
      error ??
          (c.assignment.tracksDrafts
              ? R.current.assignDraftSaved
              : R.current.assignSubmittedToast),
    ];
    // 有 result 就代表 save_submission 已經送出去了。它不是原子的：被拒絕時也要
    // 帶著重抓回來的狀態回上一頁，畫面不可以繼續拿寫入前的清單當基準。
    if (error != null && result == null) {
      return SubmitOutcome(
          messages: messages, close: false, state: _state(session));
    }
    final detail = await _closeWith(assignId, result, messages);
    return SubmitOutcome(messages: messages, close: true, detail: detail);
  }

  @override
  void cancelSubmit(int assignId) => _submits[assignId]?.controller.cancel();

  @override
  String startConfirmation(int assignId) {
    final c = _submits[assignId]!.controller;
    return MoodleAssignDetailText.startConfirmation(
        c.assignment, c.currentStatus);
  }

  @override
  Future<SubmitState> start(int assignId) async {
    final session = _submits[assignId]!;
    final outcome = await session.controller.startTimedAttempt();
    final error = outcome?.error;
    if (error != null) session.messages.add(error);
    return _state(session);
  }

  /// 「開始作答」已經寫進伺服器了就一定要把這件事帶回詳情頁：離開時什麼都不報的話，
  /// 詳情頁會停在「還沒開始」，而伺服器的鐘已經在走了。
  @override
  Future<AssignWriteResult> closeSubmit(int assignId) async {
    final c = _submits[assignId]?.controller;
    if (c == null || c.startFact.value != AssignStartFact.started) {
      _submits.remove(assignId)?.controller.dispose();
      return AssignWriteResult(messages: []);
    }
    final messages = <String>[];
    final detail = await _closeWith(assignId,
        MoodleAssignSubmitResult(status: c.refreshed.value, submitted: false),
        messages);
    return AssignWriteResult(messages: messages, detail: detail);
  }

  /// 把寫入之後的狀態帶回詳情頁；重抓失敗就自己再抓一次，否則那顆鈕還會邀請使用者再交一次。
  Future<AssignmentDetail?> _closeWith(int assignId,
      MoodleAssignSubmitResult? result, List<String> messages) async {
    _submits.remove(assignId)?.controller.dispose();
    final fresh = result?.status;
    if (fresh != null) {
      _remember(assignId, Ok(fresh));
    } else if (result != null) {
      messages.add(R.current.assignStatusRefreshFailed);
      _remember(assignId,
          await MoodleRepository.instance.getSubmissionStatus(assignId));
    }
    return _result(assignId).detail;
  }

  /// 三條寫入路徑共用的收尾：伺服器回的新狀態套上；抓不到就再抓一次。
  Future<AssignWriteResult> _afterWrite(
      int assignId, Result<MoodleAssignSubmitResult> result,
      {required String success}) async {
    final data = result.dataOrNull;
    final messages = [
      switch (result) {
        Failed(:final reason) => reason.message,
        _ => data?.error ?? success,
      },
    ];
    final fresh = data?.status;
    if (fresh != null) {
      _remember(assignId, Ok(fresh));
    } else {
      messages.add(R.current.assignStatusRefreshFailed);
      _remember(assignId,
          await MoodleRepository.instance.getSubmissionStatus(assignId));
    }
    return AssignWriteResult(
        messages: messages, detail: _result(assignId).detail);
  }

  void _remember(int assignId, Result<MoodleAssignSubmissionStatus> status) {
    _details[assignId]?.status = status;
    if (status.hasData) _memo.statuses[assignId] = status;
  }

  /// 寫入的依據：作業本體與繳交狀態兩個都要是這一趟抓到的。
  (MoodleAssignment?, MoodleAssignSubmissionStatus?) _fresh(int assignId) {
    final entry = _details[assignId];
    final a = entry?.assignment;
    final s = entry?.status;
    return (
      a is Ok<MoodleAssignment> ? a.data : null,
      s is Ok<MoodleAssignSubmissionStatus> ? s.data : null,
    );
  }

  AssignmentDetailResult _result(int assignId) {
    final entry = _details[assignId]!;
    final assignment = entry.assignment;
    final a = assignment?.dataOrNull;
    return AssignmentDetailResult(
      detail: a == null ? null : _detailOf(a, entry),
      error: a == null && assignment != null
          ? BridgeResults.errorOf(assignment)
          : null,
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  AssignmentDetail _detailOf(MoodleAssignment a, _Detail entry) {
    final now = _now();
    final statusResult = entry.status;
    final s = statusResult?.dataOrNull;
    final status =
        s == null ? null : MoodleAssignUtils.resolveStatus(a, s, now: now);
    final sub = s?.submissionFor(a);
    final shown = sub != null && (sub.isSubmitted || sub.isDraft);
    final fb = s?.feedback;
    final ext = s?.extensionDueDate ?? 0;
    final fresh = entry.assignment is Ok<MoodleAssignment> &&
        statusResult is Ok<MoodleAssignSubmissionStatus>;
    final actions = fresh
        ? MoodleAssignAttemptUtils.actionsFor(a, s!,
            api: (
              canRemove: MoodleWebApiConnector.canRemoveSubmission,
              canStart: MoodleWebApiConnector.canStartSubmission,
              canCopy: MoodleWebApiConnector.canCopyPreviousAttempt,
            ))
        : const <AssignAction>{};
    final timerState = s == null
        ? AssignTimerState.none
        : MoodleAssignAttemptUtils.timerState(a, s, now);
    final statement = a.submissionstatement ?? '';
    final intro = a.intro;
    final submit = _submitEntry(a, s, statusResult, fresh, actions);
    return AssignmentDetail(
      id: a.id,
      name: a.name,
      dueHint: dueHintText(MoodleAssignUtils.dueHint(
          MoodleAssignUtils.effectiveDueDate(a, s), now)),
      // 染紅的條件與那顆籤同源，否則會出現「已評分」卻紅字說已逾期。
      dueAlarm: status == AssignDisplayStatus.overdue,
      dueDate: a.hasDueDate ? assignFormatUnix(a.duedate) : null,
      deadlineFields: [
        if (a.allowsubmissionsfromdate > 0)
          FieldRow(
              label: R.current.assignAllowSubmissionsFrom,
              value: assignFormatUnix(a.allowsubmissionsfromdate)),
        if (ext > 0)
          FieldRow(
              label: R.current.assignExtensionDueDate,
              value: assignFormatUnix(ext)),
        if (a.cutoffdate > 0)
          FieldRow(
              label: R.current.assignCutoffDate,
              value: assignFormatUnix(a.cutoffdate)),
      ],
      chipLabel: status == null
          ? null
          : MoodleAssignText.statusLabel(status,
              extended: MoodleAssignText.isExtended(status, s)),
      chipTone: status == null ? null : CourseMoodleBridge.toneOf(status),
      chipStale: statusResult is Stale,
      statusError: s == null && statusResult != null
          ? BridgeResults.errorOf(statusResult)
          : null,
      statusFields: [
        if (s != null)
          FieldRow(
              label: R.current.assignGradingStatus,
              value: s.isGraded
                  ? R.current.assignStatusGraded
                  : R.current.assignNotGraded),
        if (shown)
          FieldRow(
            // timemodified 只有 submitted 時才是繳交時間；草稿只是最後存檔。
            label: sub.isSubmitted
                ? R.current.assignSubmittedAt
                : R.current.assignLastModified,
            value: assignFormatUnix(sub.timemodified),
          ),
      ],
      submittedFiles: shown ? _files(sub.files) : [],
      onlineTextHtml:
          shown && sub.onlineText.trim().isNotEmpty ? sub.onlineText : null,
      statusNotes: [
        if (s != null && (a.isBlindMarking || s.isBlindMarking))
          NoteRow(text: R.current.assignBlindMarkingNote, blocking: false),
      ],
      feedback: fb == null || !MoodleAssignDetailText.hasFeedbackContent(fb)
          ? null
          : AssignFeedback(
              grade: fb.gradefordisplay.trim().isEmpty
                  ? null
                  : fb.gradefordisplay,
              gradedAt: (fb.gradeddate ?? 0) > 0
                  ? assignFormatUnix(fb.gradeddate!)
                  : null,
              commentsHtml:
                  fb.commentsHtml.trim().isEmpty ? null : fb.commentsHtml,
              files: _files(fb.files),
            ),
      attempts: _attempts(a, s),
      teamNotes: [
        if (a.isTeamSubmission && s != null)
          for (final note in MoodleAssignDetailText.teamNotes(a, s))
            NoteRow(text: note.text, blocking: note.blocking),
      ],
      teamOpenInWeb: a.isTeamSubmission &&
          s != null &&
          MoodleAssignAttemptUtils.teamState(a, s) ==
              AssignTeamState.multipleGroups,
      timer: s == null || timerState == AssignTimerState.none
          ? null
          : AssignTimer(
              limit: MoodleAssignAttemptUtils.formatDuration(
                  MoodleAssignAttemptUtils.effectiveTimeLimit(a, s)),
              // 時間到不是封鎖，只是一件事實：伺服器照收，只標記遲交。
              note: timerState == AssignTimerState.expired
                  ? R.current.assignTimeExpiredStillEditable
                  : null,
              alert: false,
              endsAt: timerState == AssignTimerState.running
                  ? MoodleAssignAttemptUtils.timerEndUnix(a, s)
                  : null,
            ),
      introHtml: intro == null || intro.trim().isEmpty ? null : intro,
      introPlaceholder: intro == null
          ? R.current.assignIntroHidden
          : (intro.trim().isEmpty ? R.current.nothingHere : null),
      introHidden: intro == null,
      introFiles: _files(a.introattachments),
      entryLabel: submit.entryLabel,
      canSubmitForGrading: submit.canSubmitForGrading,
      submitNotes: submit.notes,
      needsFresh: submit.needsFresh,
      canCopyPrevious: actions.contains(AssignAction.copyPrevious),
      canRemove: actions.contains(AssignAction.removeSubmission),
      copyConfirm: MoodleAssignDetailText.copyConfirm(a),
      removeConfirm: s == null
          ? R.current.assignRemoveConfirm
          : MoodleAssignDetailText.removeConfirm(
              MoodleAssignAttemptUtils.removeConsequences(a, s)),
      statementHtml:
          a.requiresStatement && statement.trim().isNotEmpty ? statement : null,
      notice: BridgeResults.noticeOf(entry.assignment!) ??
          (statusResult == null ? null : BridgeResults.noticeOf(statusResult)),
      clockSkewSeconds: MoodleWebApiConnector.serverClockSkewSeconds,
    );
  }

  /// 繳交入口，照 `_submitSection`。
  ({
    String? entryLabel,
    bool canSubmitForGrading,
    List<NoteRow> notes,
    bool needsFresh,
  }) _submitEntry(
      MoodleAssignment a,
      MoodleAssignSubmissionStatus? s,
      Result<MoodleAssignSubmissionStatus>? statusResult,
      bool fresh,
      Set<AssignAction> actions) {
    const none = (
      entryLabel: null,
      canSubmitForGrading: false,
      notes: <NoteRow>[],
      needsFresh: false,
    );
    if (s == null) return none;
    if (!fresh) {
      return (
        entryLabel: null,
        canSubmitForGrading: false,
        notes: <NoteRow>[],
        needsFresh: true,
      );
    }
    final block = MoodleAssignSubmitUtils.blockOf(a, s);
    if (block != null) {
      final hint = MoodleAssignDetailText.blockHint(block);
      return (
        entryLabel: null,
        canSubmitForGrading: false,
        notes: [if (hint != null) NoteRow(text: hint, blocking: true)],
        needsFresh: false,
      );
    }
    // 站台沒開放那一支時選單裡根本沒有那一項，所以理由要在這裡講一次，
    // 否則使用者只會覺得那個功能不存在。
    final copyBlocked = (s.submissionFor(a)?.isReopened ?? false) &&
        !MoodleWebApiConnector.canCopyPreviousAttempt;
    final removeWebOnly = actions.contains(AssignAction.editSubmission) &&
        !MoodleWebApiConnector.canRemoveSubmission;
    return (
      entryLabel: MoodleAssignDetailText.entryLabel(actions),
      canSubmitForGrading: s.canSubmit,
      notes: [
        if (copyBlocked)
          NoteRow(text: R.current.assignCopyPreviousWebOnly, blocking: false),
        if (removeWebOnly)
          NoteRow(text: R.current.assignRemoveWebOnly, blocking: false),
      ],
      needsFresh: false,
    );
  }

  /// 次數與歷次繳交。只有真的不只一次時才畫。
  static List<FieldRow> _attempts(
      MoodleAssignment a, MoodleAssignSubmissionStatus? s) {
    if (s == null) return [];
    final label = MoodleAssignAttemptUtils.attemptLabel(a, s);
    if (label.current <= 1 && s.previousattempts.isEmpty) return [];
    return [
      FieldRow(
          label: R.current.assignCurrentAttempt,
          value: MoodleAssignDetailText.attemptLabel(label)),
      for (final p in s.previousattempts)
        FieldRow(
          label: sprintf(R.current.assignAttemptLabel, [p.attemptnumber + 1]),
          value: MoodleAssignDetailText.previousAttemptValue(p),
        ),
    ];
  }

  static List<MoodleFileRow> _files(List<MoodleAssignFile> files) => [
        for (final f in files)
          MoodleFileRow(
            name: f.filename,
            fileIcon:
                FileIconUtils.iconFor(filename: f.filename, mimetype: f.mimetype),
            url: MoodleWebApiConnector.fileUrlWithToken(f.fileurl),
          ),
      ];

  AssignTimerState _timerState(CourseAssignSubmitController c) =>
      MoodleAssignAttemptUtils.timerState(c.assignment, c.currentStatus, _now(),
          startFact: c.startFact.value);

  void _report(int assignId, CourseAssignSubmitController c) =>
      _onProgress(TransferProgress(
        key: 'assign-$assignId',
        progress: c.progress.value,
        label: MoodleAssignDetailText.transferLabel(
            c.transferFile.value, c.transferPhase.value),
        phase: c.transferPhase.value == AssignTransferPhase.download
            ? TransferPhase.download
            : TransferPhase.upload,
      ));

  SubmitState _state(_Submit session) {
    final c = session.controller;
    final a = c.assignment;
    final s = c.currentStatus;
    final now = _now();
    final status = MoodleAssignUtils.resolveStatus(a, s, now: now);
    final due = MoodleAssignUtils.effectiveDueDate(a, s);
    final timerState = _timerState(c);
    final label = MoodleAssignAttemptUtils.attemptLabel(a, s);
    final block = c.saveBlock;
    final maxFiles = MoodleAssignSubmitUtils.maxFiles(a);
    final wordLimit = c.wordLimit;
    final messages = [...session.messages];
    session.messages.clear();
    return SubmitState(
      name: a.name,
      dueHint: dueHintText(MoodleAssignUtils.dueHint(due, now)),
      dueAlarm: status == AssignDisplayStatus.overdue,
      dueLine: !a.hasDueDate
          ? null
          : (s.extensionDueDate > 0
              ? '${R.current.assignExtensionDueDate}：${assignFormatUnix(due)}'
              : assignFormatUnix(due)),
      chipLabel: MoodleAssignText.statusLabel(status),
      chipTone: CourseMoodleBridge.toneOf(status),
      timer: _submitTimer(a, s, timerState),
      teamNotice: a.isTeamSubmission ? R.current.assignTeamNotice : null,
      attemptLine: label.current > 1
          ? MoodleAssignDetailText.attemptLabel(label)
          : null,
      consequence: MoodleAssignDetailText.consequence(a, s),
      blocked: MoodleAssignSubmitUtils.blockOf(a, s) ==
          AssignSubmitBlock.unsupportedPlugin,
      filesEnabled: c.fileSubmissionEnabled,
      // 伺服器上那幾份照原順序全部畫出來，被標記移除的也在裡面：那個 X 刪的是
      // Moodle 上的檔案，一列無聲地消失講不出這件事，也沒有地方可以反悔。
      files: [
        for (final f in c.serverDrafts)
          SubmitFile(
            name: f.filename,
            subtitle: c.files.contains(f)
                ? R.current.assignFileOnServer
                : R.current.assignFileWillBeRemoved,
            fileIcon: FileIconUtils.iconFor(
                filename: f.filename, mimetype: f.mimetype),
            url: MoodleWebApiConnector.fileUrlWithToken(f.fileurl),
            onServer: true,
            removing: !c.files.contains(f),
          ),
        for (final f in c.files.whereType<LocalDraftFile>())
          SubmitFile(
            name: f.filename,
            subtitle: sprintf(R.current.assignFileJustAdded,
                [FileUtils.formatBytes(f.size, 1)]),
            fileIcon: FileIconUtils.iconFor(filename: f.filename),
            onServer: false,
            removing: false,
          ),
      ],
      pickerHint: MoodleAssignDetailText.pickerHint(a, c.files.length),
      pickerFull: c.files.length >= maxFiles,
      remainingFiles: math.max(0, maxFiles - c.files.length),
      filesNote: c.filesEmptied
          ? NoteRow(text: R.current.assignFilesEmptiedWebOnly, blocking: true)
          : (c.pendingServerRemovals > 0
              ? NoteRow(
                  text: sprintf(R.current.assignRemoveFilesWarning,
                      [c.pendingServerRemovals]),
                  blocking: true)
              : null),
      fileExtensions: MoodleAssignDetailText.pickerExtensions(
          MoodleAssignSubmitUtils.fileTypes(a)),
      textEnabled: c.onlineTextEnabled,
      textEditable: c.onlineTextEditable,
      text: c.onlineText.value,
      // 「保留原內容」是一句承諾，儲存被硬擋下來時它就是假的。
      textKept: block == null || !MoodleAssignDetailText.saveBlockIsError(block),
      wordCount: wordLimit > 0
          ? sprintf(R.current.assignWordCount,
              [c.wordCount.toString(), wordLimit.toString()])
          : null,
      overWordLimit: c.overWordLimit,
      statementRequired: c.statementRequired,
      statementHtml: c.statementRequired ? a.submissionstatement : null,
      statementAtSubmit: a.tracksDrafts,
      accepted: c.accepted.value,
      needsStart: timerState == AssignTimerState.notStarted,
      startAvailable: MoodleWebApiConnector.canStartSubmission,
      canStart: MoodleWebApiConnector.canStartSubmission && !c.starting.value,
      blockReason: block == null
          ? null
          : MoodleAssignDetailText.saveBlockMessage(block,
              textEditable: c.onlineTextEditable),
      blockIsError:
          block != null && MoodleAssignDetailText.saveBlockIsError(block),
      canSave: c.canSave,
      savesDraft: a.tracksDrafts,
      busy: c.isBusy,
      starting: c.starting.value,
      hasUnsavedChanges: c.filesChanged || c.textChanged,
      messages: messages,
    );
  }

  /// 繳交頁表頭的倒數那一行，照 `AssignSubmitStatusHeader._timerRow`。
  static AssignTimer? _submitTimer(MoodleAssignment a,
      MoodleAssignSubmissionStatus s, AssignTimerState state) {
    final limit = MoodleAssignAttemptUtils.formatDuration(
        MoodleAssignAttemptUtils.effectiveTimeLimit(a, s));
    return switch (state) {
      AssignTimerState.none => null,
      AssignTimerState.notStarted => AssignTimer(
          limit: limit,
          note: MoodleAssignDetailText.timeLimitNotice(a, s),
          alert: false),
      AssignTimerState.running => AssignTimer(
          limit: limit,
          alert: false,
          endsAt: MoodleAssignAttemptUtils.timerEndUnix(a, s)),
      // 伺服器已經開始計時，只是算不出還剩多久。退回「還沒開始」會把使用者
      // 鎖在一顆再按也沒有結果的鈕上，所以照實說。
      AssignTimerState.startedUnknown => AssignTimer(
          limit: limit, note: R.current.assignTimerStartedUnknown, alert: true),
      AssignTimerState.expired => AssignTimer(
          limit: limit,
          note: R.current.assignTimeExpiredStillEditable,
          alert: true),
    };
  }
}

class _Detail {
  _Detail(this.courseId);

  final String courseId;
  Result<MoodleAssignment>? assignment;
  Result<MoodleAssignSubmissionStatus>? status;
}

class _Submit {
  _Submit(this.controller);

  final CourseAssignSubmitController controller;

  /// 下一次回傳畫面時要 toast 的話。
  final List<String> messages = [];
}
