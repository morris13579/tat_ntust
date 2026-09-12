import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/mail_config.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/controller/mail/mail_outbox_controller.dart';
import 'package:flutter_app/src/model/mail/mail_draft.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/service/file_pick_service.dart';
import 'package:flutter_app/src/util/rich_editor_bridge_utils.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/editor/moodle_rich_editor.dart';
import 'package:flutter_app/ui/components/editor/moodle_rich_editor_toolbar.dart';
import 'package:flutter_app/ui/components/tat_progress.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_app/ui/pages/mail/components/mail_recipient_field.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

/// 寫信。
///
/// **編輯器就地嵌在這一頁**，不跳去另一頁編內容——那樣要點兩次才寫得到字，
/// 而且回來之後看到的是一段預覽而不是自己打的東西。
///
/// **一層容器，不是三層。** 先前是外面一張卡片、中間 1px 分隔線、裡面再一個
/// 圓角填色框，三個邊界在講同一件事。現在收件欄是一個 card 群組配髮線分列，
/// 標籤在左、內容在右，和個人資料頁的欄位群組同一個排法。
///
/// **副本收起來。** 大部分的信不需要副本，而它先前永遠佔一列；有副本卻又沒有
/// 密件副本。改成收件者列右邊一顆「副本」文字鈕，點了才展開兩列。
///
/// **收件者是一顆顆的籤**，見 [MailRecipientField]。逗號由欄位自己收，所以
/// 這一頁只要把 `_toList` 和還在打的那一截接起來。
///
/// 附件上限用**原始檔案大小**的 35 MB 去擋，不是伺服器回的 50 MiB：MIME 會
/// 用 base64 編碼附件，膨脹約 4/3，等寄出去才被伺服器退等於白等一輪上傳。
class MailComposePage extends StatefulWidget {
  const MailComposePage({
    super.key,
    this.initialTo = const [],
    this.initialSubject = '',
    this.initialBody = '',
  });

  final List<String> initialTo;
  final String initialSubject;

  /// 引言，純文字。這一層會轉成 HTML 餵給編輯器。
  final String initialBody;

  @override
  State<StatefulWidget> createState() => _MailComposePageState();

  /// 都在 [MailRecipientField] 那一檔，因為籤化之後兩邊都要用同一套切法與
  /// 同一套驗證。這裡留轉呼叫是為了既有的測試與呼叫端不用全部改。
  static List<String> parseAddresses(String raw) => parseMailAddresses(raw);

  static bool looksLikeAddress(String value) => looksLikeMailAddress(value);

  /// 寫信不放三級標題，理由見 [MoodleRichEditorToolbar.commands]。
  static const List<EditorCommand> toolbarCommands = [
    EditorCommand.bold,
    EditorCommand.italic,
    EditorCommand.underline,
    EditorCommand.strikeThrough,
    EditorCommand.unorderedList,
    EditorCommand.orderedList,
    EditorCommand.removeFormat,
  ];
}

class _MailComposePageState extends State<MailComposePage> {
  /// 還在打的那一截。已經收成籤的在 [_toList] 等三個清單裡。
  final _to = TextEditingController();
  final _cc = TextEditingController();
  final _bcc = TextEditingController();

  /// 回覆與轉寄帶進來的收件者直接就是籤——那些位址是伺服器給的，不用再讓
  /// 使用者確認一次。
  late final List<String> _toList = [...widget.initialTo];
  final List<String> _ccList = [];
  final List<String> _bccList = [];
  final _ccFocus = FocusNode();
  late final _subject = TextEditingController(text: widget.initialSubject);
  final _editor = MoodleRichEditorController();
  final _attachments = <File>[];

  Set<String> _active = const {};
  bool _editorReady = false;
  bool _editorFailed = false;
  bool _sourceMode = false;
  bool _sending = false;
  bool _showCopyFields = false;

  /// 內文動過沒有。回覆與轉寄帶進來的引言不算「使用者打的」，所以只看
  /// `onChanged` 有沒有被叫過。
  bool _bodyTouched = false;

  /// 已經排進寄件匣了。離開時不要再問「要放棄這封信嗎」——那封信正在寄。
  bool _queued = false;

  late final String _initialHtml = widget.initialBody.isEmpty
      ? ''
      : '<p></p>${MailConnector.plainTextToHtml(widget.initialBody)}';

  @override
  void dispose() {
    _to.dispose();
    _cc.dispose();
    _bcc.dispose();
    _ccFocus.dispose();
    _subject.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final files = await FilePickService.instance.pick(limit: 5);
      if (files.isEmpty || !mounted) return;

      var total = 0;
      for (final f in [..._attachments, ...files]) {
        total += await f.length();
      }
      if (!mounted) return;
      if (total > MailConfig.maxAttachmentBytes) {
        _toast(R.current.mailAttachTooLarge, error: true);
        return;
      }
      setState(() => _attachments.addAll(files));
    } on FilePickFailure {
      if (mounted) _toast(R.current.mailActionFailed, error: true);
    }
  }

  Future<void> _send() async {
    // 先收鍵盤：不收的話遮罩會蓋在鍵盤下面，而且寄完回到清單時鍵盤還留著。
    _dismissKeyboard();
    // 還沒收成籤的那一截也算——使用者打完最後一個位址就直接按寄出是常態，
    // 不該因為少打一個逗號就說「請至少填一位收件者」。
    final to = [..._toList, ...MailComposePage.parseAddresses(_to.text)];
    final cc = [..._ccList, ...MailComposePage.parseAddresses(_cc.text)];
    final bcc = [..._bccList, ...MailComposePage.parseAddresses(_bcc.text)];
    if (to.isEmpty) {
      _toast(R.current.mailRecipientRequired, error: true);
      return;
    }
    if (![...to, ...cc, ...bcc].every(MailComposePage.looksLikeAddress)) {
      _toast(R.current.mailInvalidRecipient, error: true);
      return;
    }

    // **null 不是空內容**：編輯器還沒接上時 content() 回 null，當成空字串會把
    // 使用者打好的信整篇清掉。那種時候退回進來時的內容。
    final html = await _editor.content() ?? _initialHtml;
    if (!mounted) return;

    setState(() => _sending = true);
    // **排進寄件匣，不在這裡等 SMTP。** 一趟寄送在手機網路上可能十幾秒，
    // 先前那段時間是一個關不掉的遮罩，按錯了也追不回來。排進佇列之後這一頁
    // 可以立刻關掉，而且接下來幾秒內收得回來，見 [MailOutboxController]。
    final queuedId = await MailOutboxController.instance.enqueue(MailDraft(
      to: to,
      cc: cc,
      bcc: bcc,
      subject: _subject.text,
      body: html,
      attachments: _attachments,
    ));
    if (!mounted) return;
    setState(() => _sending = false);

    if (queuedId != null) {
      // `_hasDraft` 還是真的，所以離開前要先把 PopScope 的確認關掉——不然
      // 使用者會看到「要放棄這封信嗎」，而那封信其實已經在寄了。
      _queued = true;
      Get.back();
      // **「收回」要跟著使用者走，不能只放在清單最上面那一段。** 捲到一半才
      // 去寫信、或寄完就切去別的分頁的話，寄件匣那一段根本不在畫面上，那五
      // 秒的窗口等於不存在。按鈕活著的時間就是窗口本身。
      TatToast.action(
        R.current.mailSendingUndo,
        actionLabel: R.current.mailRecall,
        duration: MailOutboxController.holdWindow,
        onAction: () async {
          final ok = await MailOutboxController.instance.recall(queuedId);
          TatToast.show(
            ok ? R.current.mailRecalled : R.current.mailOutboxSending,
            kind: ok ? TatToastKind.success : TatToastKind.error,
          );
        },
      );
    } else {
      // 連寫進本機佇列都失敗了。留在原地讓使用者可以再按一次，不要把辛苦
      // 打好的信直接關掉。
      _toast(R.current.mailSendFailed, error: true);
    }
  }

  /// **不要換回 `Get.snackbar`。** GetX 的 `Get.back()` 看到有 snackbar 開著
  /// 就只關 snackbar 然後 return——「先提示再離開」那一段會變成頁面關不掉。
  void _toast(String message, {bool error = false}) => TatToast.show(message,
      kind: error ? TatToastKind.error : TatToastKind.info);

  @override
  Widget build(BuildContext context) {
    final busy = _sending || !_editorReady;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_confirmLeave());
      },
      child: _buildScaffold(busy),
    );
  }

  /// 有沒有打過東西。空白不算——只點進來又退出去不該被問。
  bool get _hasDraft =>
      _toList.isNotEmpty ||
      _ccList.isNotEmpty ||
      _bccList.isNotEmpty ||
      _to.text.trim().isNotEmpty ||
      _cc.text.trim().isNotEmpty ||
      _bcc.text.trim().isNotEmpty ||
      _subject.text.trim().isNotEmpty ||
      _attachments.isNotEmpty ||
      _bodyTouched;

  /// 離開前問一次。**沒有草稿就不要問**——每次都跳一個對話框是噪音。
  Future<void> _confirmLeave() async {
    if (_sending) return; // 正在排進佇列，那一小段時間不讓走。
    if (_queued || !_hasDraft) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _dismissKeyboard();
    final discard = await showTatDialog<bool>(
      dialog: TatDialog(
        title: R.current.mailDraftDiscard,
        body: R.current.mailDraftDiscardBody,
        kind: TatDialogKind.warning,
        secondary: TatDialogAction(
          label: R.current.mailKeepEditing,
          onPressed: () => Get.back<bool>(result: false),
        ),
        primary: TatDialogAction(
          label: R.current.mailDiscard,
          onPressed: () => Get.back<bool>(result: true),
        ),
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Widget _buildScaffold(bool busy) {
    return Scaffold(
      appBar: baseAppbar(
        title: R.current.mailCompose,
        // 有草稿時返回鍵要先問。`onBack` 走的是 `Navigator.maybePop`，才會經過
        // 下面的 PopScope；`Get.back()` 是直接 pop，會跳過它。
        onBack: () => unawaited(Navigator.of(context).maybePop()),
        action: [
          IconButton(
            tooltip: R.current.mailAttach,
            onPressed: _sending ? null : () => unawaited(_pickAttachment()),
            icon: const Icon(LucideIcons.paperclip),
          ),
          // 傳送是不可復原的動作，值得一顆有字的填色鈕；光一個紙飛機圖示按
          // 下去之前不知道會發生什麼。
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            child: FilledButton.icon(
              onPressed: busy ? null : () => unawaited(_send()),
              icon: const Icon(LucideIcons.send, size: 17),
              label: Text(R.current.mailSend),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TatTokens.radiusButton),
                ),
              ),
            ),
          ),
        ],
      ),
      // 點空白處收鍵盤。整頁先前沒有任何收鍵盤的手勢，只能按返回鍵。
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissKeyboard,
        child: SafeArea(
          // **`bottom: false` 要保留。** 外層一旦吃掉底部 padding，工具列那一
          // 層的 SafeArea 就會拿到 0，又會壓在 home indicator 上。
          bottom: false,
          child: LayoutBuilder(builder: (context, area) {
            // 收件欄展開副本與密件副本之後會多兩列，先前它是 Column 的非彈性
            // 子項——長高多少就從編輯面扣多少，於是可以打字的區域被壓到只剩
            // 一條縫。給它一個上限、溢出就自己捲，編輯面留一個地板。
            //
            // **地板要連工具列與三段內距一起扣掉。** 先前只扣 `_editorMinHeight`
            // ，工具列那 64 加上 12/12/8 的內距全部是從編輯面身上拿的——鍵盤
            // 升起又展開副本時實測只剩 144，那正是「幾乎沒有空間可以填內容」。
            const chrome = _toolbarHeight + 12 + 12 + 8;
            final cap = math.max(
              area.maxHeight - _editorMinHeight - chrome,
              // 真的擠不下時至少讓收件欄看得到兩列，其餘自己捲。
              area.maxHeight * 0.28,
            );
            return Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: cap),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _headerCard(),
                        ),
                        if (_attachments.isNotEmpty)
                          Padding(
                            // 12，和上下兩段一致——先前是 8，三段節奏對不齊。
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _attachmentSection(),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    // 下緣 8：先前是 0，編輯面和工具列直接黏在一起。
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _editorArea(),
                  ),
                ),
                // 工具列自己讓開 home indicator。不要把 SafeArea 塞進元件本身
                // ——論壇編輯頁也用它，那一頁的版面已經處理過底部了。
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MoodleRichEditorToolbar(
                      active: _active,
                      enabled: _editorReady && !_sending,
                      sourceMode: _sourceMode,
                      commands: MailComposePage.toolbarCommands,
                      onToggleSource: () {
                        setState(() => _sourceMode = !_sourceMode);
                        _editor.setSourceMode(_sourceMode);
                      },
                      onCommand: (EditorCommand c) => _editor.exec(c),
                      trailing: [
                        IconButton(
                          tooltip: R.current.forumEditorHideKeyboard,
                          icon: const Icon(LucideIcons.chevronDown, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: _dismissKeyboard,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// 編輯面的高度地板。和論壇編輯頁同一個數字。
  static const double _editorMinHeight = 220;

  /// 工具列那一列的高度（`MoodleRichEditorToolbar` 的按鈕列）。算收件欄上限
  /// 時要扣掉它，不然它吃掉的高度會全部算在編輯面頭上。
  static const double _toolbarHeight = 52;

  /// 收鍵盤。**兩邊都要收**：欄位的焦點在 Flutter 這一側，編輯器的游標在
  /// WebView 裡面，只收其中一個另一個的鍵盤還留著。
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
    unawaited(_editor.blur());
  }

  /// 附件清單，帶一行群組標題——先前只有裸的幾列卡片，看不出那是一個區塊。
  Widget _attachmentSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 4, 6),
            child: Text(
              '${R.current.mailAttachments} ${_attachments.length}',
              style: context.text.titleSmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ),
          for (var i = 0; i < _attachments.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _attachmentTile(_attachments[i], i, _attachments.length),
            ),
        ],
      );

  /// 收件者、（副本、密件副本、）主旨。一張卡片配髮線分列。
  Widget _headerCard() {
    return Material(
      color: context.tokens.card,
      borderRadius: BorderRadius.circular(TatTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _recipientField(
            label: R.current.mailTo,
            controller: _to,
            addresses: _toList,
            onChanged: (next) => setState(() {
              _toList
                ..clear()
                ..addAll(next);
            }),
            // 「副本」是文字鈕不是欄位：展開之後它就沒事做了，收起來讓位。
            trailing: _showCopyFields
                ? null
                : TextButton(
                    // 展開之後把焦點交給副本那一列。先前只是 setState，新出
                    // 現的兩列既不拿焦點也不被捲進畫面，使用者按了像沒反應。
                    onPressed: () {
                      setState(() => _showCopyFields = true);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _ccFocus.requestFocus();
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(R.current.mailCc),
                  ),
          ),
          if (_showCopyFields) ...[
            _hairline(),
            _recipientField(
              label: R.current.mailCc,
              controller: _cc,
              addresses: _ccList,
              focusNode: _ccFocus,
              onChanged: (next) => setState(() {
                _ccList
                  ..clear()
                  ..addAll(next);
              }),
            ),
            _hairline(),
            _recipientField(
              label: R.current.mailBcc,
              controller: _bcc,
              addresses: _bccList,
              onChanged: (next) => setState(() {
                _bccList
                  ..clear()
                  ..addAll(next);
              }),
            ),
          ],
          _hairline(),
          _headerRow(R.current.mailSubject, _subject),
        ],
      ),
    );
  }

  Widget _hairline() =>
      Divider(height: 1, thickness: 1, color: context.scheme.outlineVariant);

  Widget _recipientField({
    required String label,
    required TextEditingController controller,
    required List<String> addresses,
    required ValueChanged<List<String>> onChanged,
    FocusNode? focusNode,
    Widget? trailing,
  }) =>
      MailRecipientField(
        label: label,
        controller: controller,
        addresses: addresses,
        onChanged: onChanged,
        isValid: MailComposePage.looksLikeAddress,
        focusNode: focusNode,
        enabled: !_sending,
        trailing: trailing,
        suggest: MailRepository.instance.suggestContacts,
      );

  /// 只剩主旨在用。
  ///
  /// **排法必須和 [MailRecipientField] 逐項一致**——同一張卡裡兩套垂直規則
  /// 就是「欄位整個歪掉」的來源：先前這一列用 Row 預設的置中加
  /// `contentPadding: 14`，收件者那三列用 `CrossAxisAlignment.start` 加
  /// 固定偏移，四個標籤的基線因此對不齊。
  Widget _headerRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          kMailFieldPadH, kMailFieldPadV, kMailFieldPadH, kMailFieldPadV),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 固定 68 寬是為了讓「密件副本」不折行、各列的內容左緣切齊；
          // 標籤本身靠左，理由見 [kMailFieldLabelWidth]。
          Padding(
            padding: const EdgeInsets.only(top: kMailFieldInputPadV),
            child: SizedBox(
              width: kMailFieldLabelWidth,
              child: Text(label, style: mailFieldLabelStyle(context)),
            ),
          ),
          const SizedBox(width: kMailFieldLabelGap),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !_sending,
              style: context.text.bodyLarge,
              // **一定要關掉 `filled`。** 主題的 `inputTheme` 預設是填色圓角
              // 框，只把 border 設成 none 的話那塊底色還在——外面一張卡片、
              // 中間一條髮線、裡面再一個填色框，正是這一版要拆掉的三層容器。
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                isDense: true,
                constraints: BoxConstraints(),
                contentPadding:
                    EdgeInsets.symmetric(vertical: kMailFieldInputPadV),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 編輯面自己一張卡，和上面的收件欄同一個層級。
  ///
  /// 空的時候給提示字：先前是一整片沒有任何提示的白，看起來像畫面沒載完。
  Widget _editorArea() {
    if (_editorFailed) {
      return Center(
        child:
            Text(R.current.mailBodyLoadFailed, style: context.text.bodyMedium),
      );
    }
    return Material(
      color: context.tokens.card,
      borderRadius: BorderRadius.circular(TatTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MoodleRichEditor(
            controller: _editor,
            initialHtml: _initialHtml,
            placeholder: R.current.mailBodyHint,
            onStateChanged: (active) {
              if (mounted) setState(() => _active = active);
            },
            onChanged: () {
              if (!_bodyTouched) _bodyTouched = true;
            },
            onReady: () {
              if (mounted) setState(() => _editorReady = true);
            },
            onLoadFailed: () {
              if (mounted) setState(() => _editorFailed = true);
            },
          ),
          if (!_editorReady) const Center(child: TatProgress()),
        ],
      ),
    );
  }

  Widget _attachmentTile(File file, int index, int length) {
    final scheme = context.scheme;
    return Material(
      color: context.tokens.card,
      borderRadius: UIUtils.getBorderRadius(index, length),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        child: Row(
          children: [
            Icon(LucideIcons.paperclip,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file.path.split(Platform.pathSeparator).last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium,
              ),
            ),
            IconButton(
              tooltip: R.current.delete,
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: () => setState(() => _attachments.remove(file)),
            ),
          ],
        ),
      ),
    );
  }
}
