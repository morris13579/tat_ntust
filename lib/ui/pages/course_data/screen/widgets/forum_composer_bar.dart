import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/ui/components/tile/moodle_file_tile.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:sprintf/sprintf.dart';

/// 討論串頁底部那條常駐的回覆列。
///
/// **回覆不換頁**：對話還在上面，被回覆的那一篇就在列的正上方，所以不需要
/// 引用區，也不需要一頁只為了兩句話。
///
/// **這條列必須住在 `Scaffold.body` 裡面**（見 `CourseForumThreadPage`）。
/// `resizeToAvoidBottomInset` 只讓 body 讓出鍵盤的高度；
/// `bottomNavigationBar` 是釘在 Scaffold 最底下量的（`_ScaffoldLayout` 的
/// `bottom` 是整個畫面高度，不扣 viewInsets），放在那裡鍵盤一開就整條被蓋住。
///
/// 送出、挑檔、取消一律由呼叫端注入：這個元件不 import repository /
/// connector / route_utils / error_page / base_page / dio。
///
/// 草稿活在這個 State 裡，**不落地**：落地要一把新的 store key，而那把 key
/// 要進 `SessionCleaner`，漏了就是跨帳號外洩。轉螢幕、鍵盤開合、切到背景都
/// 留得住，process 被殺掉才會消失。
class ForumComposerBar extends StatefulWidget {
  const ForumComposerBar({
    super.key,
    required this.hintText,
    required this.targetLabel,
    required this.topicLabel,
    required this.canAttach,
    required this.maxAttachments,
    required this.maxBytes,
    required this.onPickFiles,
    required this.onSend,
    required this.onCancelUpload,
    required this.onAimAtRoot,
    required this.onScrollToTarget,
    required this.onDraftChanged,
    required this.onBusyChanged,
  });

  final String hintText;

  /// 目前回覆對象的作者名。null ＝回第一篇（預設），那時目標列改印
  /// [topicLabel]——**列本身永遠都在**：兩種狀態長得一樣的話，捲到第 17 則
  /// 再打字的人會以為自己在回那一則。
  final String? targetLabel;

  /// 沒有指定對象時要說的「回覆主題：⋯」裡的主題名。
  final String topicLabel;

  final bool canAttach;
  final int maxAttachments;

  /// 0 ＝不知道／不限。
  final int maxBytes;

  /// 還能再挑幾個。使用者取消回空清單（不是失敗）。
  final Future<List<File>> Function(int remaining) onPickFiles;

  /// true ＝送出成功（清空欄位）；false ＝留在原地，文字與附件原封不動。
  final Future<bool> Function(
    String text,
    List<File> files, {
    required void Function(ForumTransferProgress progress) onProgress,
  }) onSend;

  /// 上傳階段的取消（頁面持有 `CancelToken`）。送出階段不給取消：
  /// `add_discussion_post` 沒有冪等鍵，請求出去就收不回來。
  final VoidCallback onCancelUpload;

  final VoidCallback onAimAtRoot;
  final VoidCallback onScrollToTarget;

  /// 回報給頁面，讓那一頁的 `PopScope` 知道還有沒有沒送出的東西。
  final void Function(bool hasDraft) onDraftChanged;
  final void Function(bool busy) onBusyChanged;

  @override
  State<ForumComposerBar> createState() => ForumComposerBarState();
}

class ForumComposerBarState extends State<ForumComposerBar> {
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  final _files = <File>[];

  /// null ＝靜止（畫一條 1px 的分隔線）。
  ForumTransferPhase? _phase;
  double? _progress;

  bool get _busy => _phase != null;

  bool get _hasDraft =>
      _messageController.text.trim().isNotEmpty || _files.isNotEmpty;

  /// 純附件回覆是合法的：一張照片本身就是內容。
  bool get _canSend =>
      !_busy &&
      (_messageController.text.trim().isNotEmpty || _files.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // 這條列被拿掉時草稿也跟著沒了，旗標一定要跟著歸零，否則頁面的
    // `PopScope` 會為一份不存在的草稿一直攔住返回鍵。排到 post-frame 是因為
    // dispose 多半發生在 build 期間，那時對父層 setState 會直接拋。
    final report = widget.onDraftChanged;
    WidgetsBinding.instance.addPostFrameCallback((_) => report(false));
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
    widget.onDraftChanged(_hasDraft);
  }

  /// 頁面瞄準某一篇時把焦點移過來：使用者按的是「回覆」，下一步一定是打字。
  void focusInput() => _focusNode.requestFocus();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final text = context.text;
    return Material(
      // SafeArea 一定要在 Material **裡面**：包在外面時讓出來的那段 inset 是
      // 透明的，底色停在 home indicator 上緣，列與螢幕底之間會露出一條頁面色。
      color: context.tokens.card,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusSlot(scheme),
            if (_files.isNotEmpty) _attachmentStrip(scheme, text),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _replyTargetStrip(scheme, text),
                  const SizedBox(height: 9),
                  // 設計稿的回覆列就是「欄位 + 44 見方的送出」兩格，間距 10，
                  // 垂直置中（Row 的預設）。
                  Row(
                    children: [
                      Expanded(child: _field(scheme, text)),
                      const SizedBox(width: 10),
                      _sendSlot(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 設計稿的欄位：高 48、圓角 14、無描邊、15px 的字。形狀一律來自主題的
  /// `InputDecorationTheme`，這裡不自己畫一個圓角盒子。
  Widget _field(ColorScheme scheme, TextTheme text) {
    // 內文預設的 1.7 會讓單行的盒子比 48 高；壓到設計稿量到的 1.4，字級才留
    // 得住 15，盒子也還停在 48。
    final body = text.bodyLarge?.copyWith(height: 1.4);
    return TextField(
      controller: _messageController,
      focusNode: _focusNode,
      // **不是 `enabled: !_busy`**：TextField 把 enabled 直接灌進 focus node
      // 的 canRequestFocus，而把它關掉會順手 unfocus——每送出一則回覆鍵盤就
      // 收一次，下一句話要先重新點一次輸入框。
      readOnly: _busy,
      minLines: 1,
      // 第 7 行起內部捲動：一條列不該把討論串擠出畫面。
      maxLines: 6,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      textAlignVertical: TextAlignVertical.center,
      style: body?.copyWith(color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: widget.hintText,
        // 提示與打出來的字同一個字級，不然一開始打字整行會跳一階。
        hintStyle: body?.copyWith(color: scheme.onSurfaceVariant),
        // 填色取與底色相反的那一階：這條列是卡片色，所以欄位填頁面色。
        fillColor: context.tokens.page,
        // 紙夾是 App 多出來的能力，設計稿上沒有；擺進欄位裡而不是自成一欄，
        // 那一列才還是設計稿的「欄位 + 送出」兩格。
        prefixIcon: widget.canAttach ? _attachButton() : null,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 42, minHeight: 24),
        // 沒有 helperText：空欄位不必被告知自己是空的。
      ),
    );
  }

  Widget _attachButton() => IconButton(
        icon: const Icon(LucideIcons.paperclip, size: 20),
        tooltip: R.current.forumAddAttachment,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
            width: TatTokens.heightButton, height: TatTokens.heightButton),
        onPressed: (_busy || _files.length >= widget.maxAttachments)
            ? null
            : () => unawaited(_pick()),
      );

  /// 固定高度 2 的槽，三態共用——列不會在忙碌時跳高。
  ///
  /// `posting` 階段刻意畫不定量：沒有東西可以量的時候，一條停在 0% 的實心條
  /// 看起來就是當掉了（理由與 `course_assign_submit_page.dart` 一字不差）。
  Widget _statusSlot(ColorScheme scheme) => SizedBox(
        height: 2,
        child: Align(
          alignment: Alignment.topCenter,
          child: switch (_phase) {
            null => Container(height: 1, color: scheme.outlineVariant),
            ForumTransferPhase.upload =>
              LinearProgressIndicator(value: _progress, minHeight: 2),
            ForumTransferPhase.posting =>
              const LinearProgressIndicator(minHeight: 2),
          },
        ),
      );

  /// 回覆對象，兩態共用同一條列——換的只是句子，不是「有沒有這條列」。
  /// 送出成功之後目標退回第一篇，那時使用者看到的是一句話變了，而不是一條列
  /// 憑空消失（而且列的高度不會跳）。
  Widget _replyTargetStrip(ColorScheme scheme, TextTheme text) {
    final target = widget.targetLabel;
    return Row(
      children: [
        Icon(LucideIcons.reply, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: widget.onScrollToTarget,
            child: Text(
              target == null
                  ? sprintf(R.current.forumReplyingToTopic, [widget.topicLabel])
                  : sprintf(R.current.forumReplyingTo, [target]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        // 已經在回第一篇了就沒有東西可以取消，那顆 x 留著只會讓人以為
        // 自己漏看了什麼。寬度用一個等寬的空盒補上，列不會左右跳。
        if (target == null)
          const SizedBox(width: 32)
        else
          IconButton(
            icon: const Icon(LucideIcons.x, size: 16),
            tooltip: R.current.forumCancelReplyTarget,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: _busy ? null : widget.onAimAtRoot,
          ),
      ],
    );
  }

  /// 附件用整條 [MoodleFileTile]，不另做一套 80×80 縮圖列：那會讓 App 出現
  /// 第二套附件 UI，而縮圖上的小移除鈕低於最小觸控目標、放大字級還要另做退路。
  /// 代價是三個檔案吃掉 120px，用內部捲動化解——第三列露一截就是「還有」的訊號。
  Widget _attachmentStrip(ColorScheme scheme, TextTheme text) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 上限只寫在這裡：紙夾撞到上限時只會變灰，不說原因等於讓人卡在那裡
          // （同 `course_assign_submit_page.dart` 的 assignFileLimit）。計數器
          // 留在捲動區外面，捲到第三個檔案時它還在。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(R.current.forumAttachments,
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                Text('${_files.length}/${widget.maxAttachments}',
                    style: text.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final f in _files)
                    MoodleFileTile(
                      filename: MoodleForumEditUtils.basename(f.path),
                      // 本機檔案沒有網址可以開；空 callback 只會給一個什麼都
                      // 不做的漣漪。
                      onTap: null,
                      trailing: IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        tooltip: R.current.forumRemoveAttachment,
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _files.remove(f);
                                  widget.onDraftChanged(_hasDraft);
                                }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );

  /// 三態，寬固定 44 所以不抖。
  ///
  /// 設計稿是一顆 44 見方、圓角 14 的實心鈕，不是 M3 的圓形 FAB。送不出去時
  /// 只是停用，**形狀與底色不換**：空欄位上換成一顆沒有底的灰圖示，打第一個
  /// 字時整顆鈕會憑空長出來。
  Widget _sendSlot() => SizedBox.square(
        dimension: TatTokens.heightButton,
        child: switch (_phase) {
          // 上傳階段可以取消：伺服器上什麼都還沒動。
          ForumTransferPhase.upload => IconButton(
              icon: const Icon(LucideIcons.x, size: 20),
              tooltip: R.current.cancel,
              padding: EdgeInsets.zero,
              onPressed: widget.onCancelUpload,
            ),
          ForumTransferPhase.posting => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          null => IconButton.filled(
              icon: const Icon(LucideIcons.send, size: 20),
              tooltip: R.current.forumSend,
              style: IconButton.styleFrom(
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(TatTokens.radiusField)),
                ),
                padding: EdgeInsets.zero,
                fixedSize: const Size.square(TatTokens.heightButton),
              ),
              onPressed: _canSend ? () => unawaited(_send()) : null,
            ),
        },
      );

  Future<void> _pick() async {
    final remaining = widget.maxAttachments - _files.length;
    if (remaining <= 0) return;
    final picked = await widget.onPickFiles(remaining);
    if (picked.isEmpty || !mounted) return;
    for (final file in picked) {
      final name = MoodleForumEditUtils.basename(file.path);
      final bytes = await file.length();
      if (!mounted) return;
      // 逐檔本地擋三件事，一律 toast——列要維持一行高，不在上面長紅字。
      if (MoodleForumEditUtils.exceedsSize(bytes, widget.maxBytes)) {
        _toast(sprintf(R.current.forumAttachmentTooLarge,
            [name, FileUtils.formatBytes(widget.maxBytes, 1)]));
        continue;
      }
      if (MoodleForumEditUtils.duplicateFilename([
            for (final f in _files) MoodleForumEditUtils.basename(f.path),
            name,
          ]) !=
          null) {
        _toast(R.current.forumAttachmentDuplicateName);
        continue;
      }
      if (_files.length >= widget.maxAttachments) {
        _toast(sprintf(R.current.forumAttachmentCountExceeded,
            [widget.maxAttachments.toString()]));
        break;
      }
      setState(() => _files.add(file));
    }
    widget.onDraftChanged(_hasDraft);
  }

  Future<void> _send() async {
    if (!_canSend) return;
    _setPhase(_files.isEmpty
        ? ForumTransferPhase.posting
        : ForumTransferPhase.upload);
    final text = _messageController.text.trim();
    final files = List<File>.from(_files);
    try {
      final ok = await widget.onSend(
        text,
        files,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _phase = progress.phase;
            _progress = progress.overall;
          });
        },
      );
      if (!mounted) return;
      if (!ok) return;
      // 送出成功：清空、保留焦點與鍵盤（對話還在進行）。
      _messageController.clear();
      setState(_files.clear);
      widget.onDraftChanged(false);
    } finally {
      if (mounted) _setPhase(null);
    }
  }

  void _setPhase(ForumTransferPhase? phase) {
    setState(() {
      _phase = phase;
      _progress = null;
    });
    widget.onBusyChanged(phase != null);
  }

  void _toast(String message) => TaskUiDelegate.instance.toast(message);
}
