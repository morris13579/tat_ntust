import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/course_data/course_assignment_controller.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_submit_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/html/moodle_html_view.dart';
import 'package:flutter_app/ui/components/page/destructive_row.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/inline_note.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/components/tile/moodle_file_tile.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_assign_submit_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/assign_status_chip.dart';
import 'package:flutter_app/ui/service/file_download.dart';
import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 一份作業的詳情。可以在 App 內交的作業會多出繳交入口，其餘一律導網頁。錯誤畫面與 WebView 開啟器
/// 由呼叫端注入，見 docs/ARCHITECTURE.md「UI 慣例」。三段 Moodle 原文 HTML
/// 都走 [MoodleHtmlView]。
class CourseAssignmentDetailPage extends StatefulWidget {
  const CourseAssignmentDetailPage(
    this.courseInfo, {
    required this.assignId,
    this.assignment,
    this.initialStatus,
    required this.errorBuilder,
    required this.openWebView,
    this.onStatusChanged,
    super.key,
  });

  final CourseInfoJson courseInfo;

  /// assign instance id（`MoodleAssignment.id` / `Modules.instance`）。
  final int assignId;

  /// 從作業分頁進來時已在手上；從「檔案」分頁進來時是 null，要抓。
  final MoodleAssignment? assignment;

  /// 只有 `hasData` 的會被沿用，Failed 會重抓。
  final Result<MoodleAssignSubmissionStatus>? initialStatus;

  final Widget Function(String message) errorBuilder;
  final WebViewOpener openWebView;

  /// 繳交成功之後把新狀態往上帶（清單頁那一列的狀態籤要跟著換）。
  final void Function(MoodleAssignSubmissionStatus status)? onStatusChanged;

  /// 同繳交頁表頭那一套，實作在 `assign_status_chip.dart`：頁面之間不互相
  /// import，共用的東西住在 widgets/。
  static String formatUnix(int unix) => assignFormatUnix(unix);

  @override
  State<CourseAssignmentDetailPage> createState() =>
      _CourseAssignmentDetailPageState();
}

class _CourseAssignmentDetailPageState
    extends State<CourseAssignmentDetailPage> {
  late final CourseAssignmentController _controller;

  /// 倒數用的秒針。只在真的有一個在跑的時限時才起，而且只有時限那一張卡的
  /// 那一列會跟著重畫（整段包在自己的 `Obx` 裡）。
  final RxInt _nowUnix = 0.obs;
  Timer? _ticker;
  Worker? _statusWatch;

  @override
  void initState() {
    super.initState();
    _controller = CourseAssignmentController(
      courseId: widget.courseInfo.main.course.id,
      assignId: widget.assignId,
      assignment: widget.assignment,
      status: widget.initialStatus,
    );
    _nowUnix.value = _serverUnix();
    // 秒針只在真的有一個在跑的時限時才起。無條件開一個 periodic timer 會讓
    // 每一份沒有時限的作業都每秒重畫一次，測試裡的 pumpAndSettle 也永遠停不下來。
    _statusWatch = ever(_controller.status, (_) => _syncTicker());
    unawaited(_controller.loadAll());
  }

  /// 依現在的狀態決定要不要讓秒針動。歸零就停：時間到不會改變任何按鈕的
  /// 可用性，只是換一行字。
  void _syncTicker() {
    final a = _controller.assignment.value?.dataOrNull;
    final s = _controller.status.value?.dataOrNull;
    final running = a != null &&
        s != null &&
        MoodleAssignAttemptUtils.timerState(a, s, _now) ==
            AssignTimerState.running;
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        _nowUnix.value = _serverUnix();
        final current = _controller.status.value?.dataOrNull;
        if (current == null ||
            MoodleAssignAttemptUtils.timerState(a, current, _now) !=
                AssignTimerState.running) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    } else if (!running) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _statusWatch?.dispose();
    _ticker?.cancel();
    _nowUnix.close();
    _controller.dispose();
    super.dispose();
  }

  DateTime get _now =>
      DateTime.fromMillisecondsSinceEpoch(_nowUnix.value * 1000);

  /// 這一頁比的每一個時間都是伺服器寫下來的，所以「現在」也要照伺服器的。
  /// 校正量由 connector 從 `Date` 標頭記下來；沒有線索時就是本機時鐘。
  static int _serverUnix() =>
      MoodleWebApiConnector.serverNow().millisecondsSinceEpoch ~/ 1000;

  String get _courseName => widget.courseInfo.main.course.name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Obx(() {
          final a = _controller.assignment.value?.dataOrNull;
          // remove 與 copy 都沒有進度框，選單收起來之後畫面上不會有任何一個
          // 地方變樣子——這一條就是「按下去真的有事情在跑」的全部證據。
          final writing =
              _controller.removing.value || _controller.copying.value;
          return Stack(
            children: [
              baseAppbar(
                title: a?.name ?? R.current.assignmentDetail,
                action: [
                  // 導網頁是最後手段，不是常見任務的答案：它從內文那顆 48pt 的
                  // 全寬鈕搬到這裡，那一頁底部才不會是三顆同等份量的鈕。
                  IconButton(
                    icon: const Icon(LucideIcons.externalLink),
                    tooltip: R.current.assignOpenInWeb,
                    onPressed:
                        a == null ? null : () => unawaited(_openInWeb(a)),
                  ),
                  if (a != null) _overflowMenu(a, writing: writing),
                ],
              ),
              // 疊在 app bar 的下緣而不是塞進 bottom：外面那層 PreferredSize
              // 的高度是寫死的 kToolbarHeight，多一列就會溢位。
              if (writing)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          );
        }),
      ),
      body: ResultView<MoodleAssignment>(
        state: _controller.assignment,
        onRetry: _controller.loadAssignment,
        errorBuilder: widget.errorBuilder,
        builder: _buildBody,
      ),
    );
  }

  Widget _buildBody(MoodleAssignment a) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        SectionHeader(
          icon: LucideIcons.calendarClock,
          title: R.current.assignDueDate,
          first: true,
        ),
        _deadlineCard(a),
        SectionHeader(
          icon: LucideIcons.clipboardCheck,
          title: R.current.assignSubmissionStatus,
          trailing: Obx(() => AssignStatusChip.fromResult(
              a, _controller.status.value,
              now: MoodleWebApiConnector.serverNow())),
        ),
        _statusCard(a),
        Obx(() => _attemptSection(a)),
        Obx(() => _teamSection(a)),
        Obx(() => _timerSection(a)),
        SectionHeader(
          icon: LucideIcons.fileText,
          title: R.current.assignIntro,
        ),
        _introCard(a),
        const SizedBox(height: 28),
        Obx(() => _submitSection(a)),
      ],
    );
  }

  /// 溢位選單。這兩件事動的是**伺服器上**的那一份而不是編輯中的草稿，所以
  /// 它們在這一頁，不在繳交頁；而「移除繳交」是全頁唯一不可逆又不是目標的
  /// 動作，跟「繳交」並排放成同等份量的鈕就是在請人把作業刪掉。
  Widget _overflowMenu(MoodleAssignment a, {required bool writing}) {
    final actions = _actionsOf(a);
    final items = <PopupMenuEntry<AssignAction>>[
      if (actions.contains(AssignAction.copyPrevious))
        PopupMenuItem<AssignAction>(
          value: AssignAction.copyPrevious,
          // 兩趟都在跑的時候整份選單都不給按：第二下會被 controller 的旗標
          // 擋掉，而那一下什麼都不會發生，看起來就是壞了。
          enabled: !writing,
          child: Row(children: [
            const Icon(LucideIcons.copy, size: 18),
            const SizedBox(width: 12),
            Text(R.current.assignCopyPrevious),
          ]),
        ),
      if (actions.contains(AssignAction.removeSubmission))
        PopupMenuItem<AssignAction>(
          value: AssignAction.removeSubmission,
          enabled: !writing,
          child: DestructiveRow.menuItem(
            icon: LucideIcons.trash2,
            label: R.current.assignRemoveSubmission,
          ),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<AssignAction>(
      icon: const Icon(LucideIcons.ellipsisVertical),
      itemBuilder: (_) => items,
      onSelected: (action) => unawaited(switch (action) {
        AssignAction.copyPrevious => _onCopyPrevious(a),
        AssignAction.removeSubmission => _onRemoveSubmission(a),
        _ => Future<void>.value(),
      }),
    );
  }

  /// 現在畫得出來的動作。兩者都是 `Ok` 才算數，理由同 [_submitSection]。
  Set<AssignAction> _actionsOf(MoodleAssignment a) {
    final assignmentResult = _controller.assignment.value;
    final statusResult = _controller.status.value;
    if (assignmentResult is! Ok<MoodleAssignment> ||
        statusResult is! Ok<MoodleAssignSubmissionStatus>) {
      return const {};
    }
    return MoodleAssignAttemptUtils.actionsFor(a, statusResult.data, api: (
      canRemove: MoodleWebApiConnector.canRemoveSubmission,
      canStart: MoodleWebApiConnector.canStartSubmission,
      canCopy: MoodleWebApiConnector.canCopyPreviousAttempt,
    ));
  }

  /// 次數與歷次繳交。只有真的不只一次時才畫——第一次就寫「第 1 次繳交」
  /// 是在替一個不存在的概念佔版面。
  Widget _attemptSection(MoodleAssignment a) {
    final s = _controller.status.value?.dataOrNull;
    if (s == null) return const SizedBox.shrink();
    final label = MoodleAssignAttemptUtils.attemptLabel(a, s);
    if (label.current <= 1 && s.previousattempts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          icon: LucideIcons.history,
          title: R.current.assignPreviousAttempts,
        ),
        SectionCard([
          SectionField(
            R.current.assignCurrentAttempt,
            label.total > 0
                ? sprintf(R.current.assignAttemptLabelOf,
                    [label.current, label.total])
                : sprintf(R.current.assignAttemptLabel, [label.current]),
          ),
          if (s.previousattempts.isNotEmpty) const SectionDivider(),
          for (final p in s.previousattempts)
            SectionField(
              sprintf(R.current.assignAttemptLabel, [p.attemptnumber + 1]),
              // 成績優先；還沒評過就講那一次交出去的時間。
              (p.grade?.hasDisplay ?? false)
                  ? p.grade!.gradefordisplay
                  : ((p.submission?.timemodified ?? 0) > 0
                      ? CourseAssignmentDetailPage.formatUnix(
                          p.submission!.timemodified)
                      : R.current.assignNotGraded),
            ),
        ]),
      ],
    );
  }

  /// 團隊作業。組員名字拿不到也不去拿：WS 只給 id，而匿名評分的作業去查名字
  /// 就是把伺服器刻意藏起來的東西挖出來。
  Widget _teamSection(MoodleAssignment a) {
    // 先讀 Rx 再做任何提早 return：Obx 的閉包裡一個 observable 都沒讀到時
    // GetX 會丟「improper use of a GetX」。
    final s = _controller.status.value?.dataOrNull;
    if (!a.isTeamSubmission || s == null) return const SizedBox.shrink();
    final state = MoodleAssignAttemptUtils.teamState(a, s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          icon: LucideIcons.users,
          title: R.current.assignTeamSubmission,
        ),
        SectionCard([
          switch (state) {
            AssignTeamState.noGroup =>
              InlineNote(R.current.assignTeamNoGroup, blocking: true),
            AssignTeamState.multipleGroups =>
              InlineNote(R.current.assignTeamMultipleGroups, blocking: true),
            AssignTeamState.notTeam ||
            AssignTeamState.ok =>
              InlineNote(R.current.assignTeamNotice),
          },
          // 全部交完時這個陣列是空的，照樣 sprintf 就會變成「還有 0 位組員
          // 尚未送出」——一句警告形狀的話貼在最好的那個狀態上。
          if (state == AssignTeamState.ok && a.requiresAllTeamMembersSubmit)
            InlineNote(s.pendingGroupMembers.isEmpty
                ? R.current.assignTeamAllSubmitted
                : sprintf(R.current.assignTeamPendingMembers,
                    [s.pendingGroupMembers.length])),
          if (state == AssignTeamState.multipleGroups) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => unawaited(_openInWeb(a)),
              icon: const Icon(LucideIcons.externalLink, size: 18),
              label: Text(R.current.assignOpenInWeb),
            ),
          ],
        ]),
      ],
    );
  }

  /// 作答時限。這裡**沒有按鈕**：按下去就開始跑的那個數字必須在同一頁看得到，
  /// 而它在繳交頁上。
  Widget _timerSection(MoodleAssignment a) {
    final s = _controller.status.value?.dataOrNull;
    if (s == null) return const SizedBox.shrink();
    final state = MoodleAssignAttemptUtils.timerState(a, s, _now);
    if (state == AssignTimerState.none) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          icon: LucideIcons.timer,
          title: R.current.assignTimeLimit,
        ),
        SectionCard([
          SectionField(
            R.current.assignTimeLimit,
            MoodleAssignAttemptUtils.formatDuration(
                MoodleAssignAttemptUtils.effectiveTimeLimit(a, s)),
          ),
          // 值就是那個數字：標籤已經說了是「剩餘時間」，再套一次「剩下 %s」
          // 會變成「剩餘時間：剩下 12:30」。
          if (state == AssignTimerState.running)
            SectionField(
              R.current.assignTimeRemaining,
              MoodleAssignAttemptUtils.formatDuration(
                  MoodleAssignAttemptUtils.timeLeftSeconds(a, s, _now)),
            ),
          // 時間到不是封鎖，只是一件事實：伺服器照收，只標記遲交。
          if (state == AssignTimerState.expired)
            InlineNote(R.current.assignTimeExpiredStillEditable),
        ]),
      ],
    );
  }

  /// 繳交入口。
  ///
  /// 作業本體與繳交狀態**兩個都必須是 `Ok`**：`submissiondrafts` 與 `configs`
  /// 是後來才新增的欄位，舊的 `cache_moodle_assign` blob 解出來全是預設值，
  /// 拿它當寫入依據會直接把草稿交出去。所以 `Stale` 一律改畫「請先重新整理」。
  Widget _submitSection(MoodleAssignment a) {
    final assignmentResult = _controller.assignment.value;
    final statusResult = _controller.status.value;
    // 還在載入或那一段已經自己畫了錯誤，這裡什麼都不加。
    if (statusResult == null || !statusResult.hasData) {
      return const SizedBox.shrink();
    }
    if (assignmentResult is! Ok<MoodleAssignment> ||
        statusResult is! Ok<MoodleAssignSubmissionStatus>) {
      return _needsFreshHint();
    }

    final status = statusResult.data;
    final block = MoodleAssignSubmitUtils.blockOf(a, status);
    if (block != null) {
      final hint = switch (block) {
        AssignSubmitBlock.unsupportedPlugin =>
          R.current.assignSubmitWebOnlyPlugin,
        AssignSubmitBlock.noGroup => R.current.assignTeamNoGroup,
        AssignSubmitBlock.multipleGroups => R.current.assignTeamMultipleGroups,
        // 伺服器說不能交時入口根本不存在，也不對著沒權限的人喊話。
        AssignSubmitBlock.closed ||
        AssignSubmitBlock.noSubmission ||
        AssignSubmitBlock.noPlugin =>
          null,
      };
      if (hint == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InlineNote(hint, blocking: true),
      );
    }

    final actions = _actionsOf(a);
    // 標籤跟著 Moodle 網頁那張按鈕表走，不是自己看 submission 是不是 null。
    final String entryLabel;
    if (actions.contains(AssignAction.addNewAttempt)) {
      entryLabel = R.current.assignStartNewAttempt;
    } else if (actions.contains(AssignAction.editSubmission)) {
      entryLabel = R.current.assignEditSubmission;
    } else {
      entryLabel = R.current.assignAddSubmission;
    }
    final canRemoveHere = actions.contains(AssignAction.editSubmission) &&
        !MoodleWebApiConnector.canRemoveSubmission;
    final copyBlocked = (status.submissionFor(a)?.isReopened ?? false) &&
        !MoodleWebApiConnector.canCopyPreviousAttempt;
    return Column(
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => unawaited(_openSubmitPage(a, status)),
          icon: const Icon(LucideIcons.filePen),
          label: Text(entryLabel),
        ),
        if (status.canSubmit) ...[
          const SizedBox(height: 8),
          // 送出評分沒有進度框，按第二下就會再發一趟，而伺服器對第二趟一律回
          // couldnotsubmitforgrading——把成功的那一次報成失敗。
          Obx(() => FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: _controller.submitting.value
                    ? null
                    : () => unawaited(_submitForGrading(a)),
                icon: const Icon(LucideIcons.send),
                label: Text(R.current.assignSubmitForGrading),
              )),
        ],
        // 站台沒開放那一支時選單裡根本沒有那一項，所以理由要在這裡講一次，
        // 否則使用者只會覺得那個功能不存在。copy 這一條在 NTUST 是常態。
        if (copyBlocked) InlineNote(R.current.assignCopyPreviousWebOnly),
        if (canRemoveHere) InlineNote(R.current.assignRemoveWebOnly),
        const SizedBox(height: 12),
      ],
    );
  }

  /// 沿用上一次的繳交。站台多半沒開放這一支，那時選單裡不會有這一項。
  Future<void> _onCopyPrevious(MoodleAssignment a) async {
    final confirmed = await _confirm(
      R.current.assignCopyPrevious,
      a.tracksDrafts
          ? R.current.assignCopyPreviousConfirm
          : '${R.current.assignCopyPreviousConfirm}\n\n'
              '${R.current.assignCopyPreviousSubmitsNow}',
    );
    if (confirmed != true) return;
    final result = await _controller.copyPreviousAttempt();
    if (result == null) return;
    TaskUiDelegate.instance
        .toast(result.error ?? R.current.assignCopyPreviousDone);
    await _afterWrite(result.fresh);
  }

  /// 移除這一次的繳交。不可逆，所以確認框要一句一句講清楚會連帶發生什麼事。
  Future<void> _onRemoveSubmission(MoodleAssignment a) async {
    final s = _controller.status.value?.dataOrNull;
    if (s == null) return;
    final c = MoodleAssignAttemptUtils.removeConsequences(a, s);
    final confirmed = await _confirm(
      R.current.assignRemoveSubmission,
      [
        R.current.assignRemoveConfirm,
        if (c.wipesTeam) R.current.assignRemoveConfirmTeam,
        if (c.unsubmits) R.current.assignRemoveConfirmSubmitted,
        if (c.keepsTimer) R.current.assignRemoveKeepsTimer,
      ].join('\n\n'),
    );
    if (confirmed != true) return;
    final result = await _controller.removeSubmission();
    if (result == null) return;
    TaskUiDelegate.instance.toast(result.error ?? R.current.assignRemoved);
    await _afterWrite(result.fresh);
  }

  /// 寫入之後的共同收尾：重抓回來的狀態往上帶；抓不到就自己再抓一次，
  /// 否則畫面會停在寫入前，那顆鈕還會邀請使用者再做一次。
  Future<void> _afterWrite(MoodleAssignSubmissionStatus? fresh) async {
    if (fresh != null) {
      widget.onStatusChanged?.call(fresh);
      return;
    }
    TaskUiDelegate.instance.toast(R.current.assignStatusRefreshFailed);
    await _reloadStatus();
  }

  /// 只有標題與內文的確認框；破壞性的那兩個動作共用。
  Future<bool?> _confirm(String title, String content) => Get.dialog<bool>(
        AlertDialog.adaptive(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text(R.current.cancel),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: Text(R.current.sure),
            ),
          ],
        ),
      );

  /// 只有一行字：`Stale` 一定伴隨 [ResultView] 的舊資料橫幅，重新整理的入口
  /// 在那上面，這裡再放一顆只是重複。
  Widget _needsFreshHint() {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        R.current.assignSubmitNeedsFresh,
        textAlign: TextAlign.center,
        style: context.text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  Future<void> _openSubmitPage(
      MoodleAssignment a, MoodleAssignSubmissionStatus status) async {
    final result =
        await Get.to<MoodleAssignSubmitResult>(() => CourseAssignSubmitPage(
              assignment: a,
              status: status,
              courseName: _courseName,
              openWebView: widget.openWebView,
            ));
    // result 非 null＝伺服器真的被寫過（成功或被拒都算）。這時候 status 為
    // null 只代表「重抓那一趟失敗」，畫面不可以就這樣留在寫入前的狀態，
    // 否則那顆鈕還會寫著「新增繳交」，邀請使用者再交一次。
    if (result == null) return;
    if (result.status != null) {
      _applyFresh(result.status);
      return;
    }
    TaskUiDelegate.instance.toast(R.current.assignStatusRefreshFailed);
    unawaited(_reloadStatus());
  }

  /// 重抓繳交狀態，抓到就往上帶：清單那一列不會自己重抓。
  Future<void> _reloadStatus() async {
    await _controller.loadStatus();
    if (!mounted) return;
    final fresh = _controller.status.value?.dataOrNull;
    if (fresh != null) widget.onStatusChanged?.call(fresh);
  }

  /// 送出評分。`requiresubmissionstatement` 在這條路上伺服器是真的會擋的
  /// （`submit_for_grading` 回 false），但它不會說原因，所以先自己要求勾選；
  /// 而且只有真的勾了才送 acceptsubmissionstatement=1——那會留下稽核事件。
  Future<void> _submitForGrading(MoodleAssignment a) async {
    final statement = a.submissionstatement ?? '';
    final needsStatement = a.requiresStatement && statement.trim().isNotEmpty;
    final accepted =
        await _confirmSubmitForGrading(a, statement, needsStatement);
    if (accepted == null) return;

    final result =
        await _controller.submitForGrading(acceptStatement: accepted);
    // null＝已經有一趟在跑，這一次連請求都沒發，不能 toast 任何結果。
    if (result == null) return;
    TaskUiDelegate.instance
        .toast(result.error ?? R.current.assignSubmittedToast);
    // 失敗也要把重抓到的狀態往上帶：清單那一列看到的必須是伺服器的真相。
    final fresh = result.fresh;
    if (fresh != null) {
      widget.onStatusChanged?.call(fresh);
      return;
    }
    // 重抓不到就自己再抓一次，否則那顆「送出評分」會一直留在畫面上。
    TaskUiDelegate.instance.toast(R.current.assignStatusRefreshFailed);
    unawaited(_reloadStatus());
  }

  /// 回 null＝取消；回 bool＝使用者是否勾了同意（不需要聲明時是 false）。
  Future<bool?> _confirmSubmitForGrading(
      MoodleAssignment a, String statement, bool needsStatement) async {
    var checked = false;
    return Get.dialog<bool>(StatefulBuilder(
      builder: (context, setInner) => AlertDialog.adaptive(
        title: Text(R.current.assignSubmitForGrading),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(R.current.assignSubmitForGradingConfirm),
              if (needsStatement) ...[
                const SizedBox(height: 12),
                _html(statement, a.name),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: checked,
                  onChanged: (v) => setInner(() => checked = v ?? false),
                  title: Text(R.current.assignAcceptStatement),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(),
            child: Text(R.current.cancel),
          ),
          TextButton(
            onPressed: (needsStatement && !checked)
                ? null
                : () => Get.back<bool>(result: checked),
            child: Text(R.current.sure),
          ),
        ],
      ),
    ));
  }

  void _applyFresh(MoodleAssignSubmissionStatus? fresh) {
    if (fresh == null) return;
    _controller.applyStatus(fresh);
    widget.onStatusChanged?.call(fresh);
  }

  Widget _deadlineCard(MoodleAssignment a) {
    final scheme = context.scheme;
    final text = context.text;
    return Obx(() {
      final now = MoodleWebApiConnector.serverNow();
      final s = _controller.status.value?.dataOrNull;
      // 染紅的條件與那顆籤同源，否則會出現「已評分」卻紅字說已逾期。
      final alarm = s != null &&
          MoodleAssignUtils.resolveStatus(a, s, now: now) ==
              AssignDisplayStatus.overdue;
      final ext = s?.extensionDueDate ?? 0;
      final specs = <Widget>[
        if (a.allowsubmissionsfromdate > 0)
          SectionField(
              R.current.assignAllowSubmissionsFrom,
              CourseAssignmentDetailPage.formatUnix(
                  a.allowsubmissionsfromdate)),
        if (ext > 0)
          SectionField(R.current.assignExtensionDueDate,
              CourseAssignmentDetailPage.formatUnix(ext)),
        if (a.cutoffdate > 0)
          SectionField(R.current.assignCutoffDate,
              CourseAssignmentDetailPage.formatUnix(a.cutoffdate)),
      ];
      return SectionCard([
        // 提示跟著生效的截止時間走，有延長期限時說「已逾期」是錯的。
        Text(
          dueHintText(MoodleAssignUtils.dueHint(
              MoodleAssignUtils.effectiveDueDate(a, s), now)),
          style: text.titleMedium?.copyWith(
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: alarm
                ? scheme.error
                : (a.hasDueDate ? scheme.onSurface : scheme.onSurfaceVariant),
          ),
        ),
        if (a.hasDueDate) ...[
          const SizedBox(height: 4),
          Text(CourseAssignmentDetailPage.formatUnix(a.duedate),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
        if (specs.isNotEmpty) ...[const SectionDivider(), ...specs],
      ]);
    });
  }

  /// 嵌在沒有高度上限的 ListView 裡所以開 `shrinkWrap`；失敗畫
  /// [InlineErrorView] 而不是整頁 errorBuilder，頁面其餘部分都還在。
  Widget _statusCard(MoodleAssignment a) {
    return ResultView<MoodleAssignSubmissionStatus>(
      shrinkWrap: true,
      state: _controller.status,
      onRetry: _controller.loadStatus,
      errorBuilder: (message) =>
          InlineErrorView(message: message, onRetry: _controller.loadStatus),
      builder: (s) => _statusGroups(a, s),
    );
  }

  Widget _statusGroups(MoodleAssignment a, MoodleAssignSubmissionStatus s) {
    final sub = s.submissionFor(a);
    final fb = s.feedback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionCard([
          SectionField(
            R.current.assignGradingStatus,
            s.isGraded
                ? R.current.assignStatusGraded
                : R.current.assignNotGraded,
          ),
          // sub 的型別提升要靠這個 inline 條件，不能先算成 bool。
          if (sub != null && (sub.isSubmitted || sub.isDraft)) ...[
            // timemodified 只有 submitted 時才是繳交時間；草稿只是最後存檔。
            SectionField(
              sub.isSubmitted
                  ? R.current.assignSubmittedAt
                  : R.current.assignLastModified,
              CourseAssignmentDetailPage.formatUnix(sub.timemodified),
            ),
            if (sub.files.isNotEmpty) ...[
              const SectionDivider(),
              SectionSubLabel(R.current.assignSubmittedFiles),
              ..._fileTiles(sub.files),
            ],
            if (sub.onlineText.trim().isNotEmpty) ...[
              const SectionDivider(),
              SectionSubLabel(R.current.assignOnlineText),
              _html(sub.onlineText, a.name),
            ],
          ],
          // 匿名評分不再是拒絕交作業的理由（伺服器端的寫入路徑從頭到尾沒有
          // 檢查它），所以它現在是一句說明：成績可能不會出現在成績簿裡。
          if (a.isBlindMarking || s.isBlindMarking)
            InlineNote(R.current.assignBlindMarkingNote),
        ]),
        if (fb != null && _hasFeedbackContent(fb)) ...[
          SectionHeader(
            icon: LucideIcons.fileCheck2,
            title: R.current.assignSectionGradeFeedback,
          ),
          _feedbackCard(a, fb),
        ],
      ],
    );
  }

  /// 四段全部落空時整個群組不畫，否則會多一張空卡。
  static bool _hasFeedbackContent(MoodleAssignFeedback fb) =>
      fb.gradefordisplay.trim().isNotEmpty ||
      (fb.gradeddate ?? 0) > 0 ||
      fb.commentsHtml.trim().isNotEmpty ||
      fb.files.isNotEmpty;

  Widget _feedbackCard(MoodleAssignment a, MoodleAssignFeedback fb) {
    final scheme = context.scheme;
    final text = context.text;
    final grade = fb.gradefordisplay.trim();
    return SectionCard([
      // gradefordisplay 是 connector 還原過的純文字，只能走 Text，
      // 不要送進 HtmlWidget（見 html_utils_sink_inventory_test）。
      if (grade.isNotEmpty) ...[
        Text(R.current.assignGrade,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(fb.gradefordisplay,
            style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w600, color: scheme.onSurface)),
        const SizedBox(height: 6),
      ],
      if ((fb.gradeddate ?? 0) > 0)
        SectionField(R.current.assignGradedAt,
            CourseAssignmentDetailPage.formatUnix(fb.gradeddate!)),
      if (fb.commentsHtml.trim().isNotEmpty) ...[
        const SectionDivider(),
        SectionSubLabel(R.current.assignFeedback),
        _html(fb.commentsHtml, a.name),
      ],
      if (fb.files.isNotEmpty) ...[
        const SectionDivider(),
        SectionSubLabel(R.current.assignFeedbackFiles),
        ..._fileTiles(fb.files),
      ],
    ]);
  }

  /// null 與空字串畫不同的東西，見 [MoodleAssignment.intro]。
  Widget _introCard(MoodleAssignment a) {
    final scheme = context.scheme;
    final text = context.text;
    final intro = a.intro;
    final Widget body;
    if (intro == null) {
      body = Text(R.current.assignIntroHidden,
          style: text.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant));
    } else if (intro.trim().isEmpty) {
      body = Text(R.current.nothingHere,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant));
    } else {
      body = _html(intro, a.name);
    }
    return SectionCard([
      body,
      if (a.introattachments.isNotEmpty) ...[
        const SectionDivider(),
        SectionSubLabel(R.current.assignAttachments),
        ..._fileTiles(a.introattachments),
      ],
    ]);
  }

  List<Widget> _fileTiles(List<MoodleAssignFile> files) {
    return [
      for (final f in files)
        MoodleFileTile(
          filename: f.filename,
          mimetype: f.mimetype,
          onTap: () => unawaited(FileDownload.download(
            context,
            MoodleWebApiConnector.fileUrlWithToken(f.fileurl),
            _courseName,
            name: f.filename,
          )),
        ),
    ];
  }

  Widget _html(String html, String title) => MoodleHtmlView(
        html: html,
        title: title,
        dirName: _courseName,
        openWebView: widget.openWebView,
      );

  /// 網頁版作業頁。這裡不呼叫 `autologinUrl`：注入的 [openWebView] 自己會換，
  /// 再換一次等於在六分鐘的伺服器節流內多燒一把鑰匙。
  Future<void> _openInWeb(MoodleAssignment a) async {
    final url = Connector.uriAddQuery(
      MoodleWebApiConnector.assignViewUrl(a.cmid),
      {"lang": LanguageUtils.getLangIndex() == LangEnum.zh ? "zh_tw" : "en"},
    );
    await widget.openWebView(a.name, url);
  }
}
