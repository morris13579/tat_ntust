import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/course_data/course_assign_submit_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart'
    show MoodleAssignSubmitResult;
import 'package:flutter_app/src/service/file_pick_service.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_submit_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/html/moodle_html_view.dart';
import 'package:flutter_app/ui/components/page/inline_note.dart';
import 'package:flutter_app/ui/components/page/note_icon.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/components/tile/moodle_file_tile.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/assign_submit_status_header.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/status_pill.dart';
import 'package:flutter_app/ui/service/file_download.dart';
import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';

/// 交作業的編輯頁。三個區：釘住的狀態表頭、會捲動的工作區、釘在底下的動作列。
///
/// 動作列是 body `Column` 的最後一個孩子而不是 `bottomNavigationBar`：
/// `resizeToAvoidBottomInset` 預設是 true，這樣鍵盤升起時整條會跟著被頂上來，
/// 而不是被蓋住。
///
/// 這一頁**沒有 overflow 選單、也沒有任何 app bar 動作**：「移除繳交」與
/// 「沿用上一次」動的是伺服器上的那一份而不是這裡的草稿，在編輯器裡跑它們
/// 會讓畫面上每一個已經 seed 好的值都變成過期的，所以它們住在詳情頁。
///
/// 沒有 `errorBuilder`：這一頁不做 `ResultView`，作業與狀態都是值傳進來的。
/// WebView 開啟器由呼叫端注入，見 docs/ARCHITECTURE.md「UI 慣例」。
class CourseAssignSubmitPage extends StatefulWidget {
  const CourseAssignSubmitPage({
    super.key,
    required this.assignment,
    required this.status,
    required this.courseName,
    required this.openWebView,
  });

  final MoodleAssignment assignment;
  final MoodleAssignSubmissionStatus status;
  final String courseName;
  final WebViewOpener openWebView;

  @override
  State<CourseAssignSubmitPage> createState() => _CourseAssignSubmitPageState();
}

class _CourseAssignSubmitPageState extends State<CourseAssignSubmitPage> {
  late final CourseAssignSubmitController _controller;
  late final TextEditingController _textController;

  /// 倒數用的秒針。只有在真的有一個在跑的時限時才起，且只有表頭那一小塊
  /// 包在 `Obx` 裡——整頁每秒重建一次是不行的。
  final RxInt _nowUnix = 0.obs;
  Timer? _ticker;

  MoodleAssignment get _assignment => widget.assignment;

  @override
  void initState() {
    super.initState();
    _controller = CourseAssignSubmitController(
      assignment: widget.assignment,
      status: widget.status,
    );
    _textController = TextEditingController(text: _controller.onlineText.value);
    _textController
        .addListener(() => _controller.onlineText.value = _textController.text);
    _nowUnix.value = _serverUnix();
    _syncTicker();
    // 存不進快取的一趟，拿來把「原樣送回」送的東西從算繪結果換成資料庫原文。
    // 失敗也不影響儲存，所以不擋畫面、不報錯。
    unawaited(_controller.loadEditableText());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _nowUnix.close();
    _textController.dispose();
    _controller.dispose();
    super.dispose();
  }

  DateTime get _now =>
      DateTime.fromMillisecondsSinceEpoch(_nowUnix.value * 1000);

  /// 倒數的兩端要來自同一個時鐘：`timestarted` 是伺服器寫的，拿裝置時鐘去減
  /// 就是把裝置慢了幾分鐘直接當成少了幾分鐘，甚至會在 running 與 expired
  /// 之間翻面。校正量由 connector 從 `Date` 標頭記下來。
  static int _serverUnix() =>
      MoodleWebApiConnector.serverNow().millisecondsSinceEpoch ~/ 1000;

  AssignTimerState get _timerState => MoodleAssignAttemptUtils.timerState(
      _assignment, _controller.currentStatus, _now,
      startFact: _controller.startFact.value);

  /// 只在倒數真的在跑的時候讓秒針動；歸零就停掉——時間到不會改變任何按鈕的
  /// 可用性，只是換一行字。
  void _syncTicker() {
    final running = _timerState == AssignTimerState.running;
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        _nowUnix.value = _serverUnix();
        if (_timerState != AssignTimerState.running) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    } else if (!running) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  int get _maxFiles => MoodleAssignSubmitUtils.maxFiles(_assignment);

  int get _maxBytes => MoodleAssignSubmitUtils.maxBytes(_assignment);

  List<String> get _fileTypes => MoodleAssignSubmitUtils.fileTypes(_assignment);

  bool get _entryBlocked =>
      MoodleAssignSubmitUtils.blockOf(_assignment, _controller.currentStatus) ==
      AssignSubmitBlock.unsupportedPlugin;

  @override
  Widget build(BuildContext context) {
    // 鍵盤的高度只有 Scaffold 外面讀得到：`resizeToAvoidBottomInset` 為真時
    // body 那一層的 viewInsets 已經被 Scaffold 扣成 0 了。
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0;
    // scaffold 先算好再包進 Obx：這樣 canPop 變動時重建的只有 PopScope 本身，
    // 底下整棵樹沿用同一個 widget 實例。
    final scaffold = Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        // baseAppbar 的返回鍵走 Get.back()＝Navigator.pop，會繞過 PopScope，
        // 所以這一頁自己接管，否則寫入到一半也按得掉。
        child: baseAppbar(
          title: _assignment.name,
          onBack: () => unawaited(_handleBack()),
        ),
      ),
      body: Column(
        children: [
          Obx(() => AssignSubmitStatusHeader(
                assignment: _assignment,
                status: _controller.currentStatus,
                now: _now,
                startFact: _controller.startFact.value,
                compact: compact,
              )),
          Expanded(
            child: Obx(() => AbsorbPointer(
                  absorbing: _controller.isBusy,
                  child: _entryBlocked ? _blockedEntry() : _buildList(),
                )),
          ),
          // 動作列刻意留在 AbsorbPointer 外面：校園網路上傳一個大檔可能很久，
          // 使用者至少要按得到「取消」。
          if (!_entryBlocked) _actionBar(),
        ],
      ),
    );
    return Obx(() => PopScope(
          // 有東西要帶回上一頁時也不能讓系統自己 pop：那樣 result 是 null，
          // 詳情頁會把「伺服器已經開始計時」當成什麼都沒發生。
          canPop: !_controller.isBusy &&
              !_controller.starting.value &&
              !_hasUnsavedChanges &&
              _startedResult == null,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            unawaited(_handleBack());
          },
          child: scaffold,
        ));
  }

  bool get _hasUnsavedChanges =>
      _controller.filesChanged || _controller.textChanged;

  /// 「開始作答」已經寫進伺服器了就一定要把這件事帶回上一頁。它是這一頁唯一
  /// 一種不會在草稿上留下痕跡的寫入：離開時報 null 的話，詳情頁與清單那一列
  /// 會停在「還沒開始」，而伺服器的鐘已經在走了。[MoodleAssignSubmitResult.status]
  /// 為 null 代表寫完之後那一趟重抓失敗，上一頁自己會再抓一次。
  MoodleAssignSubmitResult? get _startedResult =>
      _controller.startFact.value == AssignStartFact.started
          ? MoodleAssignSubmitResult(
              status: _controller.refreshed.value, submitted: false)
          : null;

  // ---------------------------------------------------------------- Zone B

  /// 這份作業開了我們送不出 plugindata 的繳交外掛，整頁只剩一條導網頁的路。
  Widget _blockedEntry() => ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        children: [
          SectionCard([
            InlineNote(R.current.assignSubmitWebOnlyPlugin, blocking: true),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => unawaited(_openInWeb()),
              icon: const Icon(LucideIcons.externalLink, size: 18),
              label: Text(R.current.assignOpenInWeb),
            ),
          ]),
        ],
      );

  Widget _buildList() {
    return ListView(
      // 底部 padding 從 32 降回 12：那 32 只是為了把鈕頂離手勢條，而現在
      // 收尾的是動作列。
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: [
        if (_controller.fileSubmissionEnabled) ...[
          SectionHeader(
            icon: LucideIcons.paperclip,
            title: R.current.assignAttachmentSection,
            first: true,
          ),
          _filesCard(),
        ],
        if (_controller.onlineTextEnabled) ...[
          SectionHeader(
            icon: LucideIcons.fileText,
            title: R.current.assignOnlineText,
            first: !_controller.fileSubmissionEnabled,
            // 「保留原內容」是一句承諾，儲存被硬擋下來時它就是假的。
            trailing: !_controller.onlineTextEditable && _onlineTextKept
                ? StatusPill(
                    tone: StatusPillTone.pending,
                    label: R.current.assignOnlineTextKeepAsIs,
                  )
                : null,
          ),
          _onlineTextCard(),
        ],
        // 有草稿階段時聲明是在「送出評分」那一步才確認的，但規則本身要在這裡
        // 看得到——否則它只活在上一頁的對話框裡，按下去才知道。
        if (_controller.statementRequired) ...[
          SectionHeader(
            icon: LucideIcons.shieldCheck,
            title: R.current.assignSubmissionStatement,
            trailing: _assignment.tracksDrafts
                ? StatusPill(
                    tone: StatusPillTone.pending,
                    label: R.current.assignStatementAtSubmit,
                  )
                : null,
          ),
          _statementCard(),
        ],
      ],
    );
  }

  Widget _filesCard() {
    return Obx(() {
      final files = _controller.files;
      // 伺服器上那幾份照原順序全部畫出來，被標記移除的也在裡面：那個 X 刪的是
      // Moodle 上的檔案，而一列無聲地消失講不出這件事，也沒有地方可以反悔。
      final rows = <Widget>[
        for (final f in _controller.serverDrafts)
          _serverFileTile(f, removing: !files.contains(f)),
        for (final f in files)
          if (f is LocalDraftFile) _localFileTile(f),
      ];
      final pending = _controller.pendingServerRemovals;
      return SectionCard([
        _pickerTile(files.length),
        if (rows.isNotEmpty) const SectionDivider(),
        ...rows,
        if (_controller.filesEmptied)
          InlineNote(R.current.assignFilesEmptiedWebOnly, blocking: true)
        else if (pending > 0)
          InlineNote(sprintf(R.current.assignRemoveFilesWarning, [pending]),
              blocking: true),
      ]);
    });
  }

  /// 已經交在 Moodle 上的那一份。[removing] 只是標記，真正的刪除要等到按下
  /// 儲存——在那之前這一列都撤得回來。
  Widget _serverFileTile(OnlineDraftFile f, {required bool removing}) =>
      MoodleFileTile(
        filename: f.filename,
        mimetype: f.mimetype,
        dimmed: removing,
        subtitle: removing
            ? R.current.assignFileWillBeRemoved
            : R.current.assignFileOnServer,
        trailing: IconButton(
          icon: Icon(removing ? LucideIcons.undo2 : LucideIcons.x, size: 18),
          tooltip: removing
              ? R.current.assignRestoreFile
              : R.current.assignRemoveFile,
          onPressed: () => removing
              ? _controller.restoreServerFile(f)
              : _controller.removeServerFile(f),
        ),
        onTap: () => _openFile(f),
      );

  /// 這次剛挑的。沒有網址可以開，就讓那一列不吃點擊——空的 callback 只會給
  /// 一個什麼都不做的漣漪。
  Widget _localFileTile(LocalDraftFile f) => MoodleFileTile(
        filename: f.filename,
        subtitle: sprintf(
            R.current.assignFileJustAdded, [FileUtils.formatBytes(f.size, 1)]),
        trailing: IconButton(
          icon: const Icon(LucideIcons.x, size: 18),
          tooltip: R.current.assignRemoveFile,
          onPressed: () => _controller.files.remove(f),
        ),
      );

  /// 挑檔案那一列。metrics 照抄 [MoodleFileTile]，它才會跟自己產生出來的那些
  /// 列站在同一個節奏上。三條限制併成一行寫在副標——從按鈕**底下**（犯了錯
  /// 才會讀到）搬到按鈕**身上**。
  Widget _pickerTile(int count) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final full = count >= _maxFiles;
    final hints = <String>[
      sprintf(R.current.assignFileLimit, [_maxFiles.toString()]),
      if (_maxBytes > 0)
        sprintf(R.current.assignFileSizeLimit,
            [FileUtils.formatBytes(_maxBytes, 1)]),
      if (_fileTypes.isNotEmpty)
        sprintf(R.current.assignFileTypes, [_fileTypes.join(', ')]),
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 28,
      horizontalTitleGap: 12,
      minVerticalPadding: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(LucideIcons.plus,
          size: 24, color: full ? scheme.onSurfaceVariant : scheme.primary),
      title: Text(R.current.assignAddFiles,
          style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: full ? scheme.onSurfaceVariant : scheme.primary)),
      subtitle: Text(
        full
            ? sprintf(R.current.assignFileLimitReached, [_maxFiles.toString()])
            : hints.join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      // 停用的控制項在控制項身上講出自己的前提。
      onTap: full ? null : () => unawaited(_pickFiles()),
    );
  }

  Widget _onlineTextCard() {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (!_controller.onlineTextEditable) {
      // 純文字框改不動這一段（圖片、排版都會被打平），但它會被原樣送回去，
      // 所以檔案照樣可以增減——導網頁只是為了改文字本身。儲存被硬擋下來時
      // 那句話就不能講：那時候一個位元組都不會送出去。
      return SectionCard([
        Text(
            _onlineTextKept
                ? R.current.assignOnlineTextPreserved
                : R.current.assignOnlineTextReadOnly,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => unawaited(_openInWeb()),
          icon: const Icon(LucideIcons.externalLink, size: 18),
          label: Text(R.current.assignEditOnlineTextInWeb),
        ),
      ]);
    }
    final wordLimit = _controller.wordLimit;
    return SectionCard([
      // 卡片本身就是輸入框的容器：在一張無邊框圓角卡裡再放一個
      // OutlineInputBorder，畫面上就是兩個互相打架的圓角矩形。
      TextField(
        controller: _textController,
        maxLines: null,
        minLines: 5,
        keyboardType: TextInputType.multiline,
        style: text.bodyMedium,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: R.current.assignOnlineTextHint,
          hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      if (wordLimit > 0) ...[
        const SectionDivider(),
        // 字數要即時算：超過上限時伺服器會拒掉整趟 save_submission，而那時
        // 檔案那半可能已經寫進去了，事後才知道太晚。
        Align(
          alignment: Alignment.centerRight,
          child: Obx(() => Text(
                sprintf(R.current.assignWordCount, [
                  _controller.wordCount.toString(),
                  wordLimit.toString(),
                ]),
                style: text.labelSmall?.copyWith(
                    color: _controller.overWordLimit
                        ? scheme.error
                        : scheme.onSurfaceVariant),
              )),
        ),
        Obx(() => _controller.overWordLimit
            ? InlineNote(R.current.assignWordCountExceeded, blocking: true)
            : const SizedBox.shrink()),
      ],
    ]);
  }

  Widget _statementCard() {
    return SectionCard([
      MoodleHtmlView(
        html: _assignment.submissionstatement ?? '',
        title: _assignment.name,
        dirName: widget.courseName,
        openWebView: widget.openWebView,
      ),
      // 有草稿階段時真正的閘門是詳情頁的「送出評分」，這裡只負責讓它不意外。
      if (!_assignment.tracksDrafts)
        Obx(() => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _controller.accepted.value,
              onChanged: (v) => _controller.accepted.value = v ?? false,
              title: Text(R.current.assignAcceptStatement),
            )),
    ]);
  }

  // ---------------------------------------------------------------- Zone C

  Widget _actionBar() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        color: scheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child:
                  Obx(() => _controller.isBusy ? _transferRow() : _actionRow()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow() {
    // 還沒開始計時的作業只有一顆鈕：先開始，倒數才會出現在上面那一條。
    if (_timerState == AssignTimerState.notStarted) return _startRow();

    final block = _controller.saveBlock;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (block != null) ...[
          _barReason(_saveBlockMessage(block), _saveBlockIsError(block)),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _controller.canSave ? () => unawaited(_onSave()) : null,
          icon: Icon(_assignment.tracksDrafts
              ? LucideIcons.filePen
              : LucideIcons.send),
          label: Text(_assignment.tracksDrafts
              ? R.current.assignSaveDraft
              : R.current.assignSubmit),
        ),
      ],
    );
  }

  Widget _startRow() {
    final available = MoodleWebApiConnector.canStartSubmission;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!available) ...[
          _barReason(R.current.assignTimerNotAvailable, false),
          const SizedBox(height: 8),
        ],
        Obx(() {
          // 先讀出來再判斷：寫成 `!available || starting.value` 的話，站台沒
          // 開放時 `||` 會短路，這個 Obx 一個 observable 都沒讀到，GetX 直接
          // 丟 improper-use 錯誤——而那正是多數站台會走到的那一條路。
          final starting = _controller.starting.value;
          return FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: (!available || starting)
                ? null
                : () => unawaited(_onStartAttempt()),
            icon: const Icon(LucideIcons.play),
            label: Text(R.current.assignStartAttempt),
          );
        }),
        if (!available)
          TextButton.icon(
            onPressed: () => unawaited(_openInWeb()),
            icon: const Icon(LucideIcons.externalLink, size: 18),
            label: Text(R.current.assignOpenInWeb),
          ),
      ],
    );
  }

  /// 理由貼在控制項上就要靠左：置中的那一種會被讀成一句對整頁說的話。
  Widget _barReason(String message, bool blocking) {
    final scheme = Theme.of(context).colorScheme;
    final color = blocking ? scheme.error : scheme.onSurfaceVariant;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteIcon(blocking ? LucideIcons.circleAlert : LucideIcons.info,
            style: style, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(message, maxLines: 2, style: style)),
      ],
    );
  }

  /// 現有的線上文字這一次到底會不會被原樣送回去。硬擋的那幾種狀態下整趟
  /// 儲存都不會發生，講「原樣送回」「檔案照樣可以增減」就是騙人。
  ///
  /// 刻意不自己包一層 `Obx`：讀它的兩處都在工作區那一個 Obx 底下，而
  /// `saveBlock` 的那幾個輸入全是短路運算——只開線上文字的作業會讓一個新的
  /// Obx 一個 observable 都沒讀到，GetX 直接丟 improper-use（同 [_startRow]）。
  bool get _onlineTextKept {
    final block = _controller.saveBlock;
    return block == null || !_saveBlockIsError(block);
  }

  /// 超過字數上限而文字框又打不開時要換一句：叫使用者刪減他在 App 裡
  /// 根本碰不到的文字是句廢話。
  String _saveBlockMessage(AssignSaveBlock block) => switch (block) {
        AssignSaveBlock.filesEmptied => R.current.assignFilesEmptiedWebOnly,
        AssignSaveBlock.overWordLimit => _controller.onlineTextEditable
            ? R.current.assignWordCountExceeded
            : R.current.assignWordCountExceededReadOnly,
        AssignSaveBlock.statementNotAccepted =>
          R.current.assignBlockedStatement,
        AssignSaveBlock.noChanges => R.current.assignBlockedNoChanges,
      };

  /// 前兩個是「這樣交出去會壞掉」，後兩個只是「還沒輪到」。
  static bool _saveBlockIsError(AssignSaveBlock block) => switch (block) {
        AssignSaveBlock.filesEmptied || AssignSaveBlock.overWordLimit => true,
        AssignSaveBlock.statementNotAccepted ||
        AssignSaveBlock.noChanges =>
          false,
      };

  Widget _transferRow() {
    final name = _controller.transferFile.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name == null
                    ? R.current.assignSubmit
                    : sprintf(
                        _controller.transferPhase.value ==
                                AssignTransferPhase.download
                            ? R.current.assignPreparingFile
                            : R.current.assignUploadingFile,
                        [name]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: _controller.cancel,
              child: Text(R.current.cancel),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // progress 是 null 就畫不定量的：只改線上文字時沒有東西可以量，
        // 一條停在 0% 的實心條看起來就是當掉了。
        LinearProgressIndicator(value: _controller.progress.value),
      ],
    );
  }

  // ------------------------------------------------------------ 寫入路徑

  Future<void> _onStartAttempt() async {
    final confirmed = await _confirm(
        R.current.assignStartAttempt,
        '${sprintf(R.current.assignTimeLimitNotice, [
              MoodleAssignAttemptUtils.formatDuration(
                  MoodleAssignAttemptUtils.effectiveTimeLimit(
                      _assignment, _controller.currentStatus))
            ])}\n\n${R.current.assignStartConfirm}');
    if (confirmed != true) return;

    final outcome = await _controller.startTimedAttempt();
    // null＝已經有一趟在跑，這一次連請求都沒發。
    if (outcome == null) return;
    if (!mounted) return;
    final error = outcome.error;
    if (error != null) {
      TaskUiDelegate.instance.toast(error);
      return;
    }
    // 重抓回來的狀態帶著 timestarted，倒數從這一刻起才算得準。
    setState(_syncTicker);
    _nowUnix.value = _serverUnix();
  }

  Future<void> _onSave() async {
    // 對話框會讓出好幾幀，回來時可能已經有一趟在跑了。
    if (_controller.isBusy) return;
    final already = _controller.currentStatus.submissionFor(_assignment);
    final expired = _timerState == AssignTimerState.expired;
    // 這一次儲存會從 Moodle 上刪掉幾個已經交出去的檔案。草稿階段的存檔本來
    // 不跳確認框，但「儲存」在這裡是不可逆的，那就一定要問。
    final removals = _controller.pendingServerRemovals;
    // 沒有草稿階段的作業「存檔」就是繳交、團隊作業會蓋掉整組的、時限過了會被
    // 標成遲交——這幾件事都得在按下去之前講。
    if (!_assignment.tracksDrafts ||
        _assignment.isTeamSubmission ||
        expired ||
        removals > 0) {
      final body = StringBuffer(_assignment.tracksDrafts
          ? R.current.assignConsequenceDraft
          : R.current.assignSubmitDirectConfirm);
      if (removals > 0) {
        body.write(
            '\n\n${sprintf(R.current.assignRemoveFilesWarning, [removals])}');
      }
      if (!_assignment.tracksDrafts && (already?.isSubmitted ?? false)) {
        body.write('\n\n${R.current.assignSubmitAgainWarning}');
      }
      if (_assignment.isTeamSubmission) {
        body.write('\n\n${R.current.assignTeamOverwriteWarning}');
      }
      // 對話框裡講，但那顆鈕從頭到尾沒有被停用過：伺服器照收，只標記遲交。
      if (expired) {
        body.write('\n\n${R.current.assignTimeExpiredStillEditable}');
      }
      final confirmed = await _confirm(
          _assignment.tracksDrafts
              ? R.current.assignSaveDraft
              : R.current.assignSubmit,
          body.toString());
      if (confirmed != true) return;
    }

    // 這一頁只負責存檔：沒有草稿階段的作業 save_submission 就是繳交，有草稿
    // 階段的則由詳情頁那顆「送出評分」接手。
    final outcome = await _controller.save(submitForGrading: false);
    // 這一次連請求都沒發（已經有一趟在跑），不可以報成功。
    if (!outcome.acted) return;

    final result = _controller.lastResult;
    final error = outcome.error;
    if (error != null) {
      TaskUiDelegate.instance.toast(error);
      if (!mounted) return;
      // 有 result 就代表 save_submission 已經送出去了。它不是原子的：一個
      // 外掛成功、另一個失敗也只回一則 warning，所以要把重抓回來的狀態帶回
      // 上一頁，畫面不可以繼續拿寫入前的清單當基準。
      if (result != null) Get.back(result: result);
      return;
    }
    TaskUiDelegate.instance.toast(_assignment.tracksDrafts
        ? R.current.assignDraftSaved
        : R.current.assignSubmittedToast);
    if (!mounted) return;
    Get.back(result: result);
  }

  // -------------------------------------------------------------- 其餘不變

  /// 已經交上去的那一份可以點開來確認；本機剛挑的沒有網址。
  Future<void> _openFile(OnlineDraftFile file) => FileDownload.download(
        context,
        MoodleWebApiConnector.fileUrlWithToken(file.fileurl),
        widget.courseName,
        name: file.filename,
      );

  /// 挑檔案。`FileType.custom` 只吃副檔名，所以只有整份清單都判讀得出來時才
  /// 交給挑選器過濾，否則挑回來自己擋。
  Future<void> _pickFiles() async {
    final remaining = _maxFiles - _controller.files.length;
    if (remaining <= 0) return;
    final types = _fileTypes;
    final extensions = types.isNotEmpty && _allExtensions(types)
        ? [for (final t in types) t.startsWith('.') ? t.substring(1) : t]
        : const <String>[];

    final List<File> picked;
    try {
      picked = await FilePickService.instance
          .pick(limit: remaining, extensions: extensions);
    } on FilePickFailure catch (e) {
      TaskUiDelegate.instance.toast(switch (e.reason) {
        FilePickFailureReason.denied => R.current.assignFilePickerDenied,
        FilePickFailureReason.unavailable =>
          R.current.assignFilePickerUnavailable,
      });
      return;
    }
    if (picked.isEmpty) return;

    for (final file in picked) {
      final name = _basename(file.path);
      if (MoodleAssignSubmitUtils.checkFileType(name, types) ==
          FileTypeCheck.rejected) {
        TaskUiDelegate.instance
            .toast(sprintf(R.current.assignFileTypeRejected, [name]));
        continue;
      }
      final bytes = await file.length();
      if (MoodleAssignSubmitUtils.exceedsSize(bytes, _maxBytes)) {
        TaskUiDelegate.instance.toast(sprintf(R.current.assignFileTooLarge,
            [name, FileUtils.formatBytes(_maxBytes, 1)]));
        continue;
      }
      final next = [
        ..._controller.files,
        LocalDraftFile(file, name, size: bytes)
      ];
      if (MoodleAssignSubmitUtils.duplicateFilename(next) != null) {
        TaskUiDelegate.instance.toast(R.current.assignFileDuplicateName);
        continue;
      }
      if (_controller.files.length >= _maxFiles) {
        TaskUiDelegate.instance.toast(
            sprintf(R.current.assignFileCountExceeded, [_maxFiles.toString()]));
        break;
      }
      _controller.files.add(LocalDraftFile(file, name, size: bytes));
    }
  }

  static bool _allExtensions(List<String> types) {
    for (final t in types) {
      if (MoodleAssignSubmitUtils.checkFileType('probe.$t', types) ==
          FileTypeCheck.unverifiable) {
        return false;
      }
      if (t.contains('/')) return false;
    }
    return true;
  }

  static String _basename(String path) {
    final index = path.lastIndexOf(RegExp(r'[/\\]'));
    return index < 0 ? path : path.substring(index + 1);
  }

  /// 返回鍵與系統手勢共用的出口。
  Future<void> _handleBack() async {
    // 寫入進行中不給走：CancelToken 到不了 save_submission，離開只會讓這一趟
    // 的結果沒有人接，上一頁停在寫入前的狀態。要停請按動作列那顆「取消」。
    // 「開始作答」也算一趟寫入：走掉的話 refreshed 會落在已經關掉的 Rx 上，
    // 那一則回應就這樣消失。
    if (_controller.isBusy || _controller.starting.value) return;
    if (!_hasUnsavedChanges) {
      Get.back(result: _startedResult);
      return;
    }
    await _confirmDiscard();
  }

  Future<void> _confirmDiscard() async {
    final confirmed = await Get.dialog<bool>(AlertDialog.adaptive(
      content: Text(R.current.assignDiscardChanges),
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
    ));
    // 問完才開始寫入的話，這裡放行等於中途離場。
    if (confirmed == true && !_controller.isBusy) {
      // 放棄的是草稿，不是「開始作答」那一趟已經寫進伺服器的事實。
      Get.back(result: _startedResult);
    }
  }

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

  Future<void> _openInWeb() async {
    final url = Connector.uriAddQuery(
      MoodleWebApiConnector.assignViewUrl(_assignment.cmid),
      {"lang": LanguageUtils.getLangIndex() == LangEnum.zh ? "zh_tw" : "en"},
    );
    await widget.openWebView(_assignment.name, url);
  }
}
