import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/components/tile/moodle_file_tile.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';

/// 撰寫頁：編輯自己的貼文。
///
/// **回覆不在這裡**：它住在討論串頁底部的 `ForumComposerBar`——對話還在上面，
/// 被回覆的那一篇就在列的正上方，不需要引用區，也不需要一頁只為了兩句話。
/// 這一頁只服務「有標題、是一件獨立的事」的動作。
///
/// 送出、挑檔、取消一律由呼叫端注入（[onSendEdit] / [onPickFiles] /
/// [onCancelUpload]），這一頁因此不碰 repository，也不需要
/// `route_utils`（見 docs/ARCHITECTURE.md「UI 慣例」）。
///
/// 成功時 `Get.back` 帶回結果，**失敗一律留在原地**：草稿不能因為送出失敗
/// 就消失，畫面也不可以看起來像已經送出去了。
class CourseForumComposePage extends StatefulWidget {
  /// 編輯自己的貼文。內文與既有附件由呼叫端預填——原文來自按下編輯時打的那趟
  /// `mod_forum_get_discussion_post`，**不是快取**（快取裡存的是算繪好的 HTML）。
  const CourseForumComposePage.edit({
    super.key,
    required this.postId,
    required this.isTopicPost,
    required this.initialSubject,
    required this.initialText,
    required this.existingAttachments,
    required this.onSendEdit,
    required this.attachPolicy,
    required this.onPickFiles,
    required this.onCancelUpload,
    required this.onOpenAttachment,
    required this.openWebView,
    required this.webUrl,
    required this.webTitle,
    this.formattingNote,
  });

  final int postId;

  /// 只有主題的第一篇才給改標題——編輯第一篇會連帶更新 `forum_discussions.name`。
  final bool isTopicPost;

  final String initialSubject;
  final String initialText;
  final List<MoodleForumFile> existingAttachments;

  final Future<Result<ForumEditOutcome>> Function(
    String subject,
    String text,
    List<MoodleForumFile> keep,
    List<File> added, {
    required void Function(ForumTransferProgress progress) onProgress,
  }) onSendEdit;

  /// `enabled == false` 時紙夾整顆不畫、也不解釋：這一頁的「沉默看起來像
  /// App 壞了」那條信條針對的是**會消失的**入口，不是**從未出現**的入口。
  final ForumAttachPolicy attachPolicy;

  final Future<List<File>> Function(int remaining) onPickFiles;
  final VoidCallback onCancelUpload;

  /// 點開伺服器上既有的那一份確認。
  final Future<void> Function(MoodleForumFile file)? onOpenAttachment;

  /// 底下那一行說明。null ＝ 預設的「粗體、清單、表格請在網頁版編輯」。
  ///
  /// **原始碼那條路一定要換掉。** `ForumEditorKind.rawSource` 填進框裡的是
  /// 貼文的原始碼（FORMAT_MARKDOWN 就是 Markdown），`plainEditPayload` 又是
  /// 原樣送回，所以 `**粗體**`、`- 清單` 打在這個框裡就會生效——照預設那句寫
  /// 等於憑空多一條「請去網頁版」的死路，而且是假的。
  final String? formattingNote;

  final WebViewOpener openWebView;

  /// 「在網頁開啟」的目標。
  final String webUrl;
  final String webTitle;

  @override
  State<CourseForumComposePage> createState() => _CourseForumComposePageState();
}

class _CourseForumComposePageState extends State<CourseForumComposePage> {
  /// 草稿活在 State 裡：轉螢幕、鍵盤開合、放棄對話框、App 切到背景都留得住，
  /// process 被殺掉才會消失。落地需要一把新的 store key，而那把 key 要進
  /// SessionCleaner，漏了就是跨帳號外洩——為了幾句話的貼文不划算。
  late final TextEditingController _messageController;
  late final TextEditingController _subjectController;

  /// 使用者決定留下的既有附件。
  late final List<MoodleForumFile> _kept;

  /// 這次新挑的檔案。
  final _files = <File>[];

  /// 送出中。擋住連點兩下送出兩次——`update_discussion_post` 沒有冪等鍵。
  bool _sending = false;

  /// 上傳中。這一段可以取消：伺服器上什麼都還沒動。
  bool _uploading = false;
  double? _progress;
  String? _transferFile;

  /// 標題計數器從這個長度開始出現，平常不掛一個 `0/255` 在那裡。
  static const int _subjectCounterFrom = 200;

  bool get _busy => _sending || _uploading;

  /// 只有主題的第一篇才給改標題。
  bool get _showSubject => widget.isTopicPost;

  int get _total => _files.length + _kept.length;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.initialText);
    _subjectController = TextEditingController(text: widget.initialSubject);
    _kept = [...widget.existingAttachments];
    _messageController.addListener(_onTextChanged);
    _subjectController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  /// 編輯的「草稿」是「跟帶進來的初值不一樣」，不是「非空」。
  bool get _hasDraft =>
      _files.isNotEmpty ||
      _messageController.text != widget.initialText ||
      _subjectController.text != widget.initialSubject ||
      _kept.length != widget.existingAttachments.length;

  bool get _canSend =>
      !_busy &&
      (_messageController.text.trim().isNotEmpty ||
          _files.isNotEmpty ||
          _kept.isNotEmpty) &&
      (!_showSubject || _subjectController.text.trim().isNotEmpty);

  /// 底列上唯一的「為什麼現在送不出去」。優先序由上而下。
  ///
  /// 規則是「已經生出內容才嘮叨」：整張表都還空著時**不佔一行**（空欄位不必
  /// 被告知自己是空的），但只要有一格填了、或已經挑了附件，另一格為什麼擋著
  /// 就一定要說——不然送出鈕只是變灰，畫面上沒有半個字解釋。
  String? get _blockReason {
    if (_sending) return R.current.forumSending;
    if (_uploading) {
      final name = _transferFile;
      return name == null
          ? R.current.forumSending
          : sprintf(R.current.assignUploadingFile, [name]);
    }
    final hasMessage = _messageController.text.trim().isNotEmpty;
    final hasSubject = _subjectController.text.trim().isNotEmpty;
    if (_showSubject && !hasSubject && (hasMessage || _total > 0)) {
      return R.current.forumSubjectRequired;
    }
    if (!hasMessage && _total == 0 && (!_showSubject || hasSubject)) {
      return R.current.forumMessageRequired;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 送出中一律擋住：那一則已經在路上了，這時離開會讓下面的 `Get.back`
      // pop 到別人的頁面，而且伺服器收下的那一則不會有人接。
      canPop: !_hasDraft && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_busy) {
          TaskUiDelegate.instance.toast(R.current.forumSending);
          return;
        }
        unawaited(_confirmDiscard());
      },
      child: Scaffold(
        appBar: baseAppbar(
          title: R.current.forumEditPost,
          // maybePop 才會經過上面那個 PopScope；直接 pop 會繞過放棄草稿的確認。
          onBack: () => Navigator.maybePop(context),
          action: [
            IconButton(
              tooltip: R.current.forumOpenInWeb,
              icon: const Icon(LucideIcons.externalLink, size: 18),
              // 送出中一律關掉。這一頁只在自己還在最上面時 pop，所以一趟
              // WebView 壓上來就會讓「已經送出去的那一則」留在螢幕上當草稿，
              // 而這一支寫入沒有冪等鍵——再按一次就是第二次更新。
              onPressed: _busy
                  ? null
                  : () => unawaited(
                      widget.openWebView(widget.webTitle, widget.webUrl)),
            ),
          ],
        ),
        body: Column(
          children: [
            _statusSlot(),
            Expanded(
              child: AbsorbPointer(absorbing: _busy, child: _form()),
            ),
          ],
        ),
        // 送出從 AppBar 搬到常駐底列：那是這一頁唯一的主要動作。
        bottomNavigationBar: _sendBar(),
      ),
    );
  }

  /// 與回覆列同一套：固定 2px 的槽，上傳有值、送出不定量。
  /// 送出階段沒有東西可以量，一條停在 0% 的實心條看起來就是當掉了。
  Widget _statusSlot() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 2,
      child: Align(
        alignment: Alignment.topCenter,
        child: _uploading
            ? LinearProgressIndicator(value: _progress, minHeight: 2)
            : _sending
                ? const LinearProgressIndicator(minHeight: 2)
                : Container(height: 1, color: scheme.outlineVariant),
      ),
    );
  }

  Widget _form() {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final policy = widget.attachPolicy;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      children: [
        SectionHeader(
          icon: LucideIcons.pencil,
          title: R.current.forumEditPost,
          first: true,
        ),
        SectionCard([
          if (_showSubject) ...[
            TextField(
              controller: _subjectController,
              enabled: !_busy,
              // 伺服器的 `name` / `subject` 都是 varchar(255)，超過會是
              // dmlwriteexception——畫面上只會看到一句通用的送出失敗，使用者
              // 永遠猜不到是標題太長。enforcement 用平台預設：中文輸入法組字
              // 中途截斷會把字吃掉，組完再截才對。
              maxLength: MoodleForumUtils.subjectMaxLength,
              buildCounter: _subjectCounter,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                labelText: R.current.forumSubject,
                hintText: R.current.forumSubjectHint,
                // helperText 拿掉了：唯一的阻塞原因住在底列，只有一個地方說話。
              ),
            ),
            const SectionDivider(),
          ],
          TextField(
            controller: _messageController,
            enabled: !_busy,
            // 不 autofocus：先讓人讀自己寫過的，不要一進來就跳鍵盤蓋住半頁。
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: text.bodyLarge?.copyWith(height: 1.55),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: R.current.forumMessageHint,
            ),
          ),
        ]),
        if (_total > 0) ...[
          SectionHeader(
            icon: LucideIcons.paperclip,
            title: R.current.forumAttachments,
            trailing: Text(
              '$_total/${policy.maxFiles}',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          SectionCard([
            for (final f in _kept)
              MoodleFileTile(
                filename: f.filename,
                // 已經在伺服器上的那一份可以點開來確認。
                onTap: widget.onOpenAttachment == null
                    ? null
                    : () => unawaited(widget.onOpenAttachment!(f)),
                trailing: IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  tooltip: R.current.forumRemoveAttachment,
                  onPressed:
                      _busy ? null : () => setState(() => _kept.remove(f)),
                ),
              ),
            for (final f in _files)
              MoodleFileTile(
                filename: MoodleForumEditUtils.basename(f.path),
                // 剛挑的本機檔案沒有網址可以開。
                onTap: null,
                trailing: IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  tooltip: R.current.forumRemoveAttachment,
                  onPressed:
                      _busy ? null : () => setState(() => _files.remove(f)),
                ),
              ),
            const SizedBox(height: 8),
            for (final hint in _attachmentHints())
              Text(hint,
                  style:
                      text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ],
        const SizedBox(height: 8),
        // 一行說明，沒有鈕：這不是一個做得到的動作，只是一件事實。
        Text(widget.formattingNote ?? R.current.forumFormattingInWeb,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }

  List<String> _attachmentHints() => [
        sprintf(R.current.forumAttachmentLimit,
            [widget.attachPolicy.maxFiles.toString()]),
        if (widget.attachPolicy.maxBytes > 0)
          sprintf(R.current.forumAttachmentSizeLimit,
              [FileUtils.formatBytes(widget.attachPolicy.maxBytes, 1)]),
      ];

  /// 只有快撞到上限時才出現：平常掛一個 `0/255` 只是雜訊。
  Widget? _subjectCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) =>
      currentLength < _subjectCounterFrom
          ? null
          : Text('$currentLength/$maxLength',
              style: Theme.of(context).textTheme.bodySmall);

  Widget _sendBar() {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reason = _blockReason;
    return SafeArea(
      top: false,
      child: Material(
        color: context.tokens.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 1, color: scheme.outlineVariant),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Icon(LucideIcons.info,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(reason,
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    // 上傳可以取消（還沒有任何東西寫進討論區）；送出不行。
                    if (_uploading)
                      TextButton(
                        onPressed: widget.onCancelUpload,
                        child: Text(R.current.cancel),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                children: [
                  if (widget.attachPolicy.enabled)
                    IconButton(
                      tooltip: R.current.forumAddAttachment,
                      icon: const Icon(LucideIcons.paperclip, size: 20),
                      onPressed:
                          (_busy || _total >= widget.attachPolicy.maxFiles)
                              ? null
                              : () => unawaited(_pick()),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(96, 48)),
                    onPressed: _canSend ? () => unawaited(_send()) : null,
                    icon: _sending
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        : const Icon(LucideIcons.send, size: 18),
                    label: Text(_sending
                        ? R.current.forumSending
                        : R.current.forumSaveEdit),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick() async {
    final policy = widget.attachPolicy;
    final remaining = policy.maxFiles - _total;
    if (remaining <= 0) return;
    final picked = await widget.onPickFiles(remaining);
    if (picked.isEmpty || !mounted) return;
    for (final file in picked) {
      final name = MoodleForumEditUtils.basename(file.path);
      final bytes = await file.length();
      if (!mounted) return;
      if (MoodleForumEditUtils.exceedsSize(bytes, policy.maxBytes)) {
        TaskUiDelegate.instance.toast(sprintf(R.current.forumAttachmentTooLarge,
            [name, FileUtils.formatBytes(policy.maxBytes, 1)]));
        continue;
      }
      // 跨「保留的既有附件」與「新挑的」兩份清單一起擋重名：既有附件會被
      // prepare_draft_area_for_post 種進 draft 區，同名的新檔案會回
      // filenameexist，而那時 draft 區已經是半套的。
      if (MoodleForumEditUtils.duplicateFilename([
            for (final f in _kept) f.filename,
            for (final f in _files) MoodleForumEditUtils.basename(f.path),
            name,
          ]) !=
          null) {
        TaskUiDelegate.instance.toast(R.current.forumAttachmentDuplicateName);
        continue;
      }
      if (_total >= policy.maxFiles) {
        TaskUiDelegate.instance.toast(sprintf(
            R.current.forumAttachmentCountExceeded,
            [policy.maxFiles.toString()]));
        break;
      }
      setState(() => _files.add(file));
    }
  }

  void _onProgress(ForumTransferProgress progress) {
    if (!mounted) return;
    setState(() {
      _uploading = progress.phase == ForumTransferPhase.upload;
      _sending = progress.phase == ForumTransferPhase.posting;
      _progress = progress.overall;
      _transferFile = progress.filename;
    });
  }

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() {
      _sending = _files.isEmpty;
      _uploading = _files.isNotEmpty;
      _progress = null;
      _transferFile = null;
    });
    final message = _messageController.text.trim();
    final subject = _subjectController.text.trim();
    try {
      final result = await widget.onSendEdit(subject, message, _kept, _files,
          onProgress: _onProgress);
      switch (result) {
        case Ok(:final data):
          // 只 pop 自己。`Get.back` 會 pop 最上面那一個，而不是「這一頁」，
          // 一旦這一頁已經不在最上面就會把別人的頁面關掉。
          if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
            Get.back(result: data);
          }
        // 送出失敗（含 Stale——寫入路徑本來就沒有快取可退）：留在原地、
        // 文字與附件原封不動，只吐一句已經對應好的訊息。
        case Stale(:final reason):
        case Failed(:final reason):
          TaskUiDelegate.instance.toast(reason.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _uploading = false;
          _progress = null;
          _transferFile = null;
        });
      }
    }
  }

  /// 放棄草稿是破壞性的是非題：主鈕換 error 底，問句本身就是標題。
  Future<void> _confirmDiscard() async {
    final discard = await showTatDialog<bool>(
      dialog: TatDialog(
        title: R.current.forumDiscardDraft,
        body: null,
        kind: TatDialogKind.warning,
        destructive: true,
        secondary: TatDialogAction(
          label: R.current.cancel,
          onPressed: () => Get.back<bool>(result: false),
        ),
        primary: TatDialogAction(
          label: R.current.sure,
          onPressed: () => Get.back<bool>(result: true),
        ),
      ),
    );
    if (discard != true || !mounted) return;
    Get.back();
  }
}
