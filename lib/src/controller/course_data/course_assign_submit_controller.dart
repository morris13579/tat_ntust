import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart'
    show AssignStartOutcome;
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/moodle_assign_attempt_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_submit_utils.dart';
import 'package:get/get.dart';

/// 繳交編輯頁的狀態。普通類別而不是 GetxController：生命週期就是那一個頁面，
/// 同 CourseAssignmentController。
class CourseAssignSubmitController {
  CourseAssignSubmitController({
    required this.assignment,
    required this.status,
  }) {
    final sub = status.submissionFor(assignment);
    _serverFiles = sub?.files ?? const [];
    _serverOnlineText = sub?.onlineText ?? '';
    _serverDrafts = [
      for (final f in _serverFiles)
        OnlineDraftFile(f.filename, f.fileurl,
            mimetype: f.mimetype, filesize: f.filesize),
    ];
    files.assignAll(_serverDrafts);
    onlineText.value = MoodleAssignSubmitUtils.htmlToPlain(_serverOnlineText);
  }

  final MoodleAssignment assignment;

  /// 進頁時的那一份。只有它決定草稿的初值——重抓回來的那一份不可以拿去
  /// 重新 seed，使用者可能已經在打字了。
  final MoodleAssignSubmissionStatus status;

  /// 「開始作答」寫入之後重抓回來的那一份。`start_submission` 只會寫
  /// `timestarted`，繳交內容不動，所以只換這一個參考、不重 seed。
  final Rxn<MoodleAssignSubmissionStatus> refreshed =
      Rxn<MoodleAssignSubmissionStatus>();

  /// 現在該拿來算倒數與狀態的那一份。
  MoodleAssignSubmissionStatus get currentStatus => refreshed.value ?? status;

  late final List<MoodleAssignFile> _serverFiles;

  /// **算繪過的**那一份線上文字：[status] 是 `moodlewssettingfilter=true`
  /// 抓回來的。只拿來當輸入框的初值與 [textChanged] 的基準，
  /// **永遠不可以送回伺服器**，見 [onlineTextNeedsRaw]。
  late final String _serverOnlineText;
  late final List<OnlineDraftFile> _serverDrafts;

  /// 伺服器上已經交了的檔案，給畫面比對用。
  List<MoodleAssignFile> get serverFiles => _serverFiles;

  /// 伺服器上那幾份的草稿列，照伺服器的順序，**被標記移除的也還在裡面**。
  /// 畫面要照這一份畫，不是照 [files]：`files_filemanager` 是同步不是附加，
  /// 從清單裡消失就等於儲存時會被 Moodle 刪掉，那件事不可以只用一下無聲的
  /// 消失來表示。
  List<OnlineDraftFile> get serverDrafts => _serverDrafts;

  /// 這一次儲存會從 Moodle 上刪掉幾個已經交出去的檔案。
  int get pendingServerRemovals =>
      filesChanged ? _serverDrafts.where((f) => !files.contains(f)).length : 0;

  /// 把伺服器上的那一份標記成「儲存後移除」。那一列不會消失，只是換一個樣子，
  /// 而且刪除要等到真的按下儲存才發生。
  void removeServerFile(OnlineDraftFile file) => files.remove(file);

  /// 取消移除。一定要插回原來的位置：[MoodleAssignSubmitUtils.fileListChanged]
  /// 是逐格比對的，接在最後面會讓「什麼都沒動」被算成有變更，白白重傳整份清單。
  void restoreServerFile(OnlineDraftFile file) {
    if (files.contains(file)) return;
    final target = _serverDrafts.indexOf(file);
    if (target < 0) return;
    var at = 0;
    for (var i = 0; i < target; i++) {
      if (files.contains(_serverDrafts[i])) at++;
    }
    files.insert(at, file);
  }

  /// 初值＝伺服器上的那一份。
  final RxList<AssignDraftFile> files = <AssignDraftFile>[].obs;

  /// 初值＝現有線上文字還原成的純文字。
  final RxString onlineText = ''.obs;

  final RxBool accepted = false.obs;

  /// 有沒有一趟寫入正在跑。跟 [progress] 分開：只改線上文字時沒有任何檔案
  /// 可以量，那時候要畫不定量的進度條，而不是一條停在 0% 的實心條。
  final RxBool busy = false.obs;

  /// 有沒有一趟「開始作答」正在跑。跟 [busy] 分開：它不是傳輸，動作列畫的
  /// 還是同一顆鈕，只是不能再按第二下——第二下會拿到 opensubmissionexists。
  final RxBool starting = false.obs;

  /// 「開始作答」那一趟寫入回報的事實。**沒有任何狀態欄位講得出這兩件事**：
  /// 站台關掉 `enabletimelimit` 時 `timelimit` 照樣是原值，重抓失敗時
  /// `timestarted` 照樣是 0，兩者看起來都跟「還沒開始」一模一樣，而動作列在
  /// 那個狀態下只畫得出「開始作答」——沒有這一顆，儲存鈕永遠出不來。
  final Rxn<AssignStartFact> startFact = Rxn<AssignStartFact>();

  /// 0..1；量不出來時是 null。
  final Rxn<double> progress = Rxn<double>();

  /// 正在處理的那個檔名；沒有在傳檔案時是 null。
  final RxnString transferFile = RxnString();

  /// [transferFile] 現在在哪一段。
  final Rx<AssignTransferPhase> transferPhase = AssignTransferPhase.upload.obs;

  bool get isBusy => busy.value;

  CancelToken? _cancelToken;

  /// 這一趟之後的結果，頁面用它把新狀態帶回上一頁。被伺服器拒絕時也會有值：
  /// `save_submission` 不是原子的，那時候的狀態才是唯一的真相。
  MoodleAssignSubmitResult? lastResult;

  bool get fileSubmissionEnabled => MoodleAssignSubmitUtils.pluginEnabled(
      assignment, MoodleAssignSubmitUtils.pluginFile);

  bool get onlineTextEnabled => MoodleAssignSubmitUtils.pluginEnabled(
      assignment, MoodleAssignSubmitUtils.pluginOnlineText);

  /// 現有的線上文字適不適合用純文字框編輯。**這只決定開不開輸入框**，
  /// 跟能不能儲存無關：含圖片的文字照樣存得回去，見 [outgoingOnlineText]。
  /// 也跟要不要去問原文無關，見 [onlineTextNeedsRaw]。
  bool get onlineTextEditable =>
      onlineTextEnabled &&
      MoodleAssignSubmitUtils.onlineTextIsPlain(_serverOnlineText);

  /// raw 那一趟拿回來的原文；還沒回來或拿不到是 null。
  /// **只給 [outgoingOnlineText] 讀**，不可以拿去重 seed 輸入框。
  final Rxn<AssignOnlineTextEdit> editText = Rxn<AssignOnlineTextEdit>();

  /// 這一次要送進 `plugindata[onlinetext_editor][text]` 的字串。
  ///
  /// 沒開 onlinetext 外掛時是 null，那時候整個鍵都不送。**外掛開著卻回 null
  /// 代表這一次不可以送**：資料庫原文還沒到手，見 [onlineTextRawMissing]。
  /// 伺服器的 `save()` 沒有 isset 把關，缺這個鍵等於用空值覆蓋掉學生的文字，
  /// 所以 [save] 會整趟擋下來，而不是讓 null 流下去。
  ///
  /// 還原 `@@PLUGINFILE@@` 對原文通常是 identity（原文本來就帶佔位字串），
  /// 留著是為了站台無視 `moodlewssettingfileurl=false` 的那一種。
  String? get outgoingOnlineText {
    if (!onlineTextEnabled) return null;
    if (textChanged) {
      return MoodleAssignSubmitUtils.plainToHtml(onlineText.value);
    }
    final fresh = _freshEditText;
    if (fresh == null) return _serverOnlineText.isEmpty ? '' : null;
    return MoodleAssignSubmitUtils.restorePluginfileUrls(
      fresh.rawText,
      fresh.inlineFiles,
    );
  }

  /// 沒動過的文字要原樣送回去時，送出去的必須是**資料庫原文**，也就是
  /// [loadEditableText] 那一趟拿回來的那一份。
  ///
  /// [_serverOnlineText] 不行：`core\formatting::format_text` 已經對它跑完
  /// 每一個啟用中的 filter（MathJax 會把整段包進
  /// `<span class="filter_mathjaxloader_equation">`、活動名稱會被塞進
  /// `<a class="autolink">`）再過一次 HTML Purifier（不合規的標籤直接消失）。
  /// 而 `file_postupdate_standard_editor` 的 `empty($editor['itemid'])` 分支是
  /// `$data->onlinetext = $editor['text']`——送什麼位元組就永久存什麼，於是
  /// 算繪的痕跡被存成學生的原文，每存一次再包一層，Purifier 丟掉的救不回來。
  bool get onlineTextNeedsRaw =>
      onlineTextEnabled && !textChanged && _serverOnlineText.isNotEmpty;

  /// 原文還沒到手（那一趟還在路上，或失敗了）。[save] 會自己再問一次。
  bool get onlineTextRawMissing => onlineTextNeedsRaw && _freshEditText == null;

  /// 原文那一趟的成果，拿不到就是 null。
  ///
  /// 原文是空字串時也當成沒拿到：文字真的是空的時候根本不會走到這裡
  /// （[onlineTextNeedsRaw] 已經是 false），所以空字串只可能是回應不對，
  /// 照收就是把學生的文字清掉。
  AssignOnlineTextEdit? get _freshEditText {
    final edit = editText.value;
    return (edit != null && edit.rawText.isNotEmpty) ? edit : null;
  }

  /// 去問一次資料庫原文。**不可以動 [onlineText] 與 [_serverOnlineText]**：
  /// 那兩個是輸入框的初值與 [textChanged] 的基準。
  ///
  /// 文字框開得起來的那一份也要問：只改檔案、文字一個字都沒動時，送回去的
  /// 一樣是那份算繪過的，見 [onlineTextNeedsRaw]。失敗就留著 null，[save]
  /// 會再試一次。
  Future<void> loadEditableText() async {
    if (!onlineTextNeedsRaw) return;
    editText.value = await MoodleRepository.instance
        .fetchOnlineTextForEdit(assignment: assignment);
  }

  bool get filesChanged =>
      fileSubmissionEnabled &&
      MoodleAssignSubmitUtils.fileListChanged(files, _serverFiles);

  /// 伺服器上原本有檔案卻被清空。`files_filemanager` 是同步不是附加，送一個
  /// 空的 draft 區等於把繳交檔案全部刪掉；v1 不做這件事，要刪請到網頁。
  bool get filesEmptied =>
      fileSubmissionEnabled && _serverFiles.isNotEmpty && files.isEmpty;

  bool get textChanged =>
      onlineTextEditable &&
      onlineText.value !=
          MoodleAssignSubmitUtils.htmlToPlain(_serverOnlineText);

  /// `wordlimitenabled` 為假時是 0。
  int get wordLimit => MoodleAssignSubmitUtils.wordLimit(assignment);

  int get wordCount => MoodleAssignSubmitUtils.countWords(onlineText.value);

  /// 伺服器的 `check_word_count` 失敗只回一句 `couldnotsavesubmission`，連
  /// 「是字數超過」都說不出來，而那時候檔案那半可能已經寫進去了：
  /// `save_submission` 是一個迴圈跑完所有外掛的 `save()`，onlinetext 回 false
  /// 之前，file 外掛那一個可能已經同步過 filemanager 了。
  ///
  /// **沒動過的文字也要算**：老師事後調低 `wordlimit` 時，原樣送回去一樣會
  /// 被擋。[wordCount] 算的是 `htmlToPlain` 的產物，會比伺服器少算
  /// （不補區塊標籤的空白、只還原六個實體），所以它可能漏擋，但不會擋掉
  /// 一個本來交得出去的。
  bool get overWordLimit =>
      onlineTextEnabled && wordLimit > 0 && wordCount > wordLimit;

  /// 沒開草稿又要求同意聲明時，伺服器不會擋，只能由 App 自己要求勾選。
  bool get statementRequired =>
      assignment.requiresStatement &&
      (assignment.submissionstatement ?? '').trim().isNotEmpty;

  bool get _statementOk =>
      !(statementRequired && !assignment.tracksDrafts) || accepted.value;

  /// 儲存鈕為什麼不能按；null = 可以存。**作答時限到期不在裡面**：伺服器
  /// 照收只標記遲交，本地擋下來就是把寫好的東西鎖死在畫面上。
  AssignSaveBlock? get saveBlock => MoodleAssignSubmitUtils.saveBlockOf(
        filesEmptied: filesEmptied,
        overWordLimit: overWordLimit,
        statementOk: _statementOk,
        dirty: filesChanged || textChanged,
      );

  /// [isBusy] 刻意不是 [AssignSaveBlock] 的一員：忙碌時動作列畫的是傳輸列
  /// 而不是這顆鈕，那個理由字串永遠不會被畫出來。
  bool get canSave => !isBusy && saveBlock == null;

  /// 開始一次有時限的作答。回 null 代表已經有一趟在跑；否則 error 為 null
  /// 才是成功。不開對話框也不 toast：controller -> ui 是上行邊。
  Future<({String? error})?> startTimedAttempt() async {
    if (starting.value) return null;
    starting.value = true;
    try {
      final result = await MoodleRepository.instance
          .startAssignAttempt(assignment: assignment);
      final data = result.dataOrNull;
      final fresh = data?.status;
      if (fresh != null) refreshed.value = fresh;
      final outcome = data?.outcome;
      if (outcome != null) startFact.value = _factOf(outcome);
      return switch (result) {
        Ok() || Stale() => (error: null),
        Failed(:final reason) => (error: reason.message),
      };
    } finally {
      starting.value = false;
    }
  }

  static AssignStartFact? _factOf(AssignStartOutcome outcome) =>
      switch (outcome) {
        AssignStartOutcome.noTimeLimit => AssignStartFact.noTimeLimit,
        AssignStartOutcome.started ||
        AssignStartOutcome.alreadyRunning =>
          AssignStartFact.started,
        // notOpen 走的是 Failed，這裡拿不到它。
        AssignStartOutcome.notOpen => null,
      };

  /// 送出一次繳交。不開對話框、不 toast：controller → ui 是上行邊，確認框與
  /// 提示由頁面負責。
  Future<AssignSaveOutcome> save({required bool submitForGrading}) async {
    // 回「成功」是不行的：畫面會 toast「作業已繳交」再帶著空的 lastResult
    // 收工。canSave 與 AbsorbPointer 都是下一幀才生效，擋不住同一幀的第二下。
    if (isBusy) return const AssignSaveOutcome(acted: false);
    final token = CancelToken();
    _cancelToken = token;
    busy.value = true;
    progress.value = null;
    try {
      // 原文那一趟是進頁時發的，使用者一秒多之後就按得到儲存，所以它可能還在
      // 路上；失敗過的那一次也留著 null。這裡再問一次，問不到就整趟都不送。
      if (onlineTextRawMissing) await loadEditableText();
      final outgoing = outgoingOnlineText;
      // 拿不到原文寧可什麼都不做：算繪過的那一份寫回去是永久的，而少存這一次
      // 只是要使用者再按一次。
      if (onlineTextEnabled && outgoing == null) {
        return AssignSaveOutcome(
            acted: true, error: R.current.assignOnlineTextRawFailed);
      }
      final result = await MoodleRepository.instance.saveAssignSubmission(
        assignment: assignment,
        status: currentStatus,
        draft: AssignSubmissionDraft(
          onlineText: outgoing,
          files: filesChanged ? List<AssignDraftFile>.of(files) : null,
          submitForGrading: submitForGrading,
          acceptStatement: accepted.value,
        ),
        onProgress: (p) {
          progress.value = p.overall;
          transferFile.value = p.filename;
          transferPhase.value = p.phase;
        },
        cancelToken: token,
      );
      switch (result) {
        case Ok(:final data):
        case Stale(:final data):
          lastResult = data;
          return AssignSaveOutcome(acted: true, error: data.error);
        case Failed(:final reason):
          // 使用者自己按的取消不是「繳交失敗」。
          return AssignSaveOutcome(
            acted: true,
            error: token.isCancelled
                ? R.current.assignSubmitCancelled
                : reason.message,
          );
      }
    } finally {
      busy.value = false;
      progress.value = null;
      transferFile.value = null;
      _cancelToken = null;
    }
  }

  /// 取消進行中的傳輸。只擋得住下載與上傳那幾趟——`save_submission` 一旦送出
  /// 就沒有回頭路，中止連線只會讓我們不知道伺服器到底存了沒有。
  void cancel() {
    _cancelToken?.cancel('cancelled by user');
  }

  void dispose() {
    cancel();
    files.close();
    onlineText.close();
    editText.close();
    transferFile.close();
    transferPhase.close();
    accepted.close();
    refreshed.close();
    starting.close();
    startFact.close();
    busy.close();
    progress.close();
  }
}

/// [CourseAssignSubmitController.save] 的結果。「忙碌」與「成功」必須分得開：
/// 兩者共用一個 null 就會把「什麼都沒做」報成「已繳交」。
class AssignSaveOutcome {
  const AssignSaveOutcome({required this.acted, this.error});

  /// false = 已經有一趟在跑，這一次連請求都沒發。
  final bool acted;

  /// null = 完全成功；否則是要 toast 的那一句。
  final String? error;
}
