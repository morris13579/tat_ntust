import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/file/file_store.dart';
import 'package:flutter_app/src/model/mail/mail_content.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/repository/mail_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/card/section_card.dart';
import 'package:flutter_app/ui/components/html/no_embedded_web_view_factory.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/tat_progress.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_app/ui/pages/mail/mail_compose_page.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';

/// 給 [HtmlWidget.factoryBuilder] 的具名 tear-off：closure 每次 build 都是新
/// 物件，會讓 HtmlWidget 整棵重建。
WidgetFactory _mailHtmlWidgetFactory() => NoEmbeddedWebViewFactory();

/// 深色模式換這一個：信件自己寫死的顏色要中和掉。
///
/// 校內公告幾乎都是從 Word 或 Outlook 貼出來的，滿滿的 `color:#000`；不中和
/// 的話深色底配黑字，整封信看起來像壞掉。`MoodleHtmlView` 對教材做的是同一件事。
WidgetFactory _mailHtmlWidgetFactoryDark() =>
    NoEmbeddedWebViewFactory(neutralizeColors: true);

/// 一封信的內文。
///
/// **頂部列不放標題。** 使用者剛從信箱點進來，再寫一次「校內信箱」不帶資訊，
/// 還會把真正的主旨擠進卡片裡截斷。主旨移到內容區當大標，愛多長就多長。
///
/// **三個箭頭分級。** 回覆、全部回覆、轉寄先前同樣大小並排在頂部列，圖形差別
/// 只有箭頭數量——誤按「全部回覆」是寄給三個大宗郵件群組。現在回覆下放到底部
/// 當填色主鈕，另外兩個縮成旁邊的 tonal 鈕；頂部列改放封存與刪除，破壞性動作
/// 離拇指遠一點。
///
/// **內文滿版、不包卡片。** 信件內文是整個 App 唯一不是我們排版的內容——寄件者
/// 的 HTML、固定寬度的表格、1000px 寬的海報，全都不知道我們的邊距存在。其餘
/// （主旨、寄件者、附件、通知條）是 App 自己的東西，照樣留在 16px 的邊距裡。
///
/// 內文**刻意不快取**：它塞不進信件快取那張表，每次重抓的代價是一次連線。
/// 見 docs/WEBMAIL_IMAP.md §4.5。
class MailDetailPage extends StatefulWidget {
  const MailDetailPage({
    super.key,
    required this.message,
    this.folderPath = MailRepository.inboxPath,
  });

  final MailMessageJson message;

  /// 這封信在哪個資料夾。封存與刪除要從那裡搬走，寫死收件匣的話在回收筒裡
  /// 按刪除會去動收件匣裡 UID 剛好相同的另一封信。
  final String folderPath;

  @override
  State<StatefulWidget> createState() => _MailDetailPageState();

  @visibleForTesting
  static Widget? imageLoadingBuilder(
      BuildContext context, dom.Element element, double? progress) {
    final src = element.attributes['src'] ?? '';
    if (src.startsWith('data:') || src.startsWith('cid:')) {
      return const SizedBox.shrink();
    }
    return const Center(
      child: Padding(padding: EdgeInsets.all(8), child: TatProgress()),
    );
  }
}

class _MailDetailPageState extends State<MailDetailPage> {
  final _content = Rxn<Result<MailContent>>();

  /// 正在下載的附件 fetchId。同一個附件不要讓使用者連按兩次各抓一份。
  final _downloading = <String>{};

  /// 遠端圖片預設不載入，由使用者自己決定要不要放行。只影響這一次瀏覽。
  bool _showRemoteImages = false;

  /// 收件者展開了沒有。預設收起來：大宗郵件的收件者是投遞群組位址，對讀信的
  /// 人沒有用，但它一佔就是兩三行。
  bool _showRecipients = false;

  bool _busy = false;

  static const EdgeInsets _sidePadding = EdgeInsets.symmetric(horizontal: 16);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _content.close();
    super.dispose();
  }

  Future<void> _load() async {
    _content.value = null;
    _content.value = await MailRepository.instance
        .getContent(widget.message.uid, folderPath: widget.folderPath);
  }

  Future<void> _downloadAttachment(MailAttachment attachment) async {
    if (_downloading.contains(attachment.fetchId)) return;
    setState(() => _downloading.add(attachment.fetchId));
    try {
      final bytes = await MailRepository.instance.fetchAttachment(
          widget.message.uid, attachment.fetchId,
          folderPath: widget.folderPath);
      if (!mounted) return;
      if (bytes == null) {
        _toast(R.current.mailActionFailed, error: true);
        return;
      }
      // 走跟課程檔案同一個下載目錄，使用者只要記得一個地方。
      final dir = await FileStore.getDownloadDir(context, R.current.mailTitle);
      if (!mounted) return;
      if (dir.isEmpty) return; // 沒有權限，FileStore 已經提示過了。
      final path = '$dir/${attachment.name}';
      await File(path).writeAsBytes(bytes);
      if (!mounted) return;
      _toast(R.current.mailDownloaded);
      await FileUtils.openFile(path);
    } finally {
      if (mounted) setState(() => _downloading.remove(attachment.fetchId));
    }
  }

  /// **不要換回 `Get.snackbar`。** GetX 的 `Get.back()` 看到有 snackbar 開著
  /// 就只關 snackbar 然後 return——「先提示再離開」那一段會變成頁面關不掉。
  void _toast(String message, {bool error = false}) => TatToast.show(message,
      kind: error ? TatToastKind.error : TatToastKind.info);

  /// 封存或刪除。成功就帶著 `true` 回上一頁，讓清單知道要重抓。
  Future<void> _move({required bool archive}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = archive
        ? await MailRepository.instance
            .moveToArchive(widget.message.uid, folderPath: widget.folderPath)
        : await MailRepository.instance
            .moveToTrash(widget.message.uid, folderPath: widget.folderPath);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      _toast(R.current.mailActionFailed, error: true);
      return;
    }
    // **先離開再提示。** 反過來寫的話，任何會插一條 route 的浮層（例如
    // Get.snackbar）都會把這次 pop 吃掉，按鈕看起來就像沒反應。
    Get.back(result: true);
    _toast(archive ? R.current.mailArchived : R.current.mailMovedToTrash);
  }

  /// 目前顯示的內文，轉成逐行加上「> 」的引言。抓不到就給空字串——引言是
  /// 加分項，沒有它照樣可以回信。
  String get _quotedBody {
    final html = _content.value?.dataOrNull?.html ?? '';
    if (html.isEmpty) return '';
    return MailConnector.htmlToPlainText(html)
        .split('\n')
        .map((line) => '> ${line.trimRight()}')
        .join('\n');
  }

  Future<void> _reply({required bool all}) async {
    final message = widget.message;
    final to = <String>[
      if (message.fromEmail.isNotEmpty) message.fromEmail,
      // 全部回覆才把原信的收件者與副本帶上，而且要把自己剔掉——不然每回一次
      // 就多寄一封給自己。
      if (all) ...[...message.to, ...message.cc],
    ];
    final own = MailConnector.accountToAddress(Model.instance.getAccount())
        .toLowerCase();
    final unique = <String>[];
    for (final address in to) {
      final normalized = address.trim();
      if (normalized.isEmpty) continue;
      if (normalized.toLowerCase() == own) continue;
      if (unique.any((e) => e.toLowerCase() == normalized.toLowerCase())) {
        continue;
      }
      unique.add(normalized);
    }

    await Get.to(
      () => MailComposePage(
        initialTo: unique,
        initialSubject: _prefixed('Re: ', message.subject),
        initialBody: '\n\n$_quotedBody',
      ),
      transition: RouteUtils.transition,
    );
  }

  Future<void> _forward() async {
    await Get.to(
      () => MailComposePage(
        initialSubject: _prefixed('Fwd: ', widget.message.subject),
        initialBody: '\n\n$_quotedBody',
      ),
      transition: RouteUtils.transition,
    );
  }

  /// 已經有前綴就不再加一次，免得變成 `Re: Re: Re:`。
  static String _prefixed(String prefix, String subject) =>
      subject.toLowerCase().startsWith(prefix.toLowerCase())
          ? subject
          : '$prefix$subject';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(LucideIcons.chevronLeft, size: 18),
          onPressed: Get.back,
        ),
        actions: [
          IconButton(
            tooltip: R.current.mailFolderArchive,
            icon: const Icon(LucideIcons.archive),
            onPressed: _busy ? null : () => unawaited(_move(archive: true)),
          ),
          IconButton(
            tooltip: R.current.delete,
            icon: const Icon(LucideIcons.trash2),
            onPressed: _busy ? null : () => unawaited(_move(archive: false)),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(padding: _sidePadding, child: _subject()),
                  Padding(padding: _sidePadding, child: _senderCard()),
                  ResultView<MailContent>(
                    state: _content,
                    shrinkWrap: true,
                    onRetry: _load,
                    errorBuilder: (msg) => Padding(
                      padding: _sidePadding,
                      child: InlineErrorView(message: msg, onRetry: _load),
                    ),
                    builder: _buildContent,
                  ),
                ],
              ),
            ),
            _actionBar(),
          ],
        ),
      ),
    );
  }

  /// 主旨。**不截斷**，多長畫多長——這是整頁唯一說明「這是哪一封信」的東西。
  Widget _subject() {
    final subject = widget.message.subject.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Text(
        subject.isEmpty ? R.current.mailNoSubject : subject,
        style: context.text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: context.scheme.onSurface,
        ),
      ),
    );
  }

  Widget _senderCard() {
    final message = widget.message;
    final scheme = context.scheme;
    final text = context.text;
    final recipients = [...message.to, ...message.cc];

    return Material(
      color: context.tokens.card,
      borderRadius: BorderRadius.circular(TatTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.displayFrom,
                  style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600, color: scheme.onSurface),
                ),
                if (message.fromEmail.isNotEmpty &&
                    message.fromEmail != message.displayFrom)
                  Text(message.fromEmail,
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                Text(
                  DateFormat('yyyy/MM/dd HH:mm').format(message.date),
                  style:
                      text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (recipients.isNotEmpty) _recipientsRow(recipients),
        ],
      ),
    );
  }

  /// 「收件者 N 位」，點了才展開。
  ///
  /// 大宗郵件的收件者是 `stud-xxxx-xd@ns.ntust.edu.tw` 這種投遞群組別名，一列
  /// 就佔掉兩行、而且對讀信的人沒有用；但「這封是不是只寄給我」有時候要看，
  /// 所以收起來而不是拿掉。
  Widget _recipientsRow(List<String> recipients) {
    final scheme = context.scheme;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        InkWell(
          onTap: () => setState(() => _showRecipients = !_showRecipients),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sprintf(R.current.mailRecipientCount, [recipients.length]),
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                Icon(
                  _showRecipients
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_showRecipients)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
            // **收件者與副本要分開列。** 先前是一整串接在一起，看不出哪些是
            // 直接寄給你的、哪些只是副本——而「這封是不是只寄給我」正是使用者
            // 展開這一列想知道的事。自己的位址標出來，理由同上。
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.message.to.isNotEmpty)
                  _recipientGroup(R.current.mailRecipientTo, widget.message.to),
                if (widget.message.cc.isNotEmpty)
                  _recipientGroup(R.current.mailCc, widget.message.cc),
              ],
            ),
          ),
      ],
    );
  }

  /// 「收件者：a、b」的一組。自己的位址加一個「（我）」，一眼看得出這封是
  /// 直接寄給你的還是你只是副本。
  Widget _recipientGroup(String label, List<String> addresses) {
    final own = MailConnector.accountToAddress(Model.instance.getAccount())
        .toLowerCase();
    final text = context.text;
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$label：',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          for (var i = 0; i < addresses.length; i++) ...[
            if (i > 0) const TextSpan(text: '、'),
            TextSpan(
              text: addresses[i],
              style: addresses[i].trim().toLowerCase() == own
                  ? TextStyle(
                      color: scheme.onSurface, fontWeight: FontWeight.w600)
                  : null,
            ),
            if (addresses[i].trim().toLowerCase() == own)
              TextSpan(
                text: ' ${R.current.mailSelfMarker}',
                style: TextStyle(color: scheme.primary),
              ),
          ],
        ]),
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _attachmentSection(List<MailAttachment> attachments) {
    return Padding(
      padding: _sidePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: '${R.current.mailAttachments} ${attachments.length}',
          ),
          for (var i = 0; i < attachments.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            _attachmentTile(attachments[i], i, attachments.length),
          ],
        ],
      ),
    );
  }

  Widget _attachmentTile(MailAttachment attachment, int index, int length) {
    final scheme = context.scheme;
    final busy = _downloading.contains(attachment.fetchId);
    return Material(
      color: context.tokens.card,
      borderRadius: UIUtils.getBorderRadius(index, length),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Icon(LucideIcons.paperclip,
                size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(attachment.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge
                          ?.copyWith(color: scheme.onSurface)),
                  if (_attachmentMeta(attachment) case final meta?)
                    Text(meta,
                        style: context.text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 下載鈕給滿 44：先前是一顆 18px 的圖示，整列可點但看起來不像。
            SizedBox(
              width: TatTokens.heightButton,
              height: TatTokens.heightButton,
              child: busy
                  ? const Center(child: TatProgress(size: 18))
                  : IconButton(
                      tooltip: R.current.mailDownload,
                      style: IconButton.styleFrom(
                        backgroundColor: context.tokens.page,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(TatTokens.radiusButton),
                        ),
                      ),
                      icon: Icon(LucideIcons.download,
                          size: 20, color: scheme.primary),
                      onPressed: () =>
                          unawaited(_downloadAttachment(attachment)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 「PNG · 1.2 MB」。兩個都問不到就不畫這一行。
  String? _attachmentMeta(MailAttachment attachment) {
    final size = attachment.readableSize;
    final type = attachment.mediaType.split('/').last.toUpperCase();
    final parts = [
      if (type.isNotEmpty) type,
      if (size != null) size,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// 遠端圖片的提示。
  ///
  /// **不用 `NoticeBar`**：那個元件是釘在內容區頂端的滿版提示條，沒有圓角。
  /// 這裡照這一頁自己的卡片樣式畫，位階同內建瀏覽器的 `BrowserNoticeBar`——
  /// 它講的是 App 做了什麼，不是信的內容，所以自己一張卡、不混進信裡面。
  Widget _remoteImageCard() {
    final scheme = context.scheme;
    return Padding(
      padding: _sidePadding.add(const EdgeInsets.only(top: 14)),
      child: Material(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(TatTokens.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.imageOff,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      R.current.mailRemoteImagesBlocked,
                      style: context.text.bodySmall
                          ?.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(() => _showRemoteImages = true),
                      child: Text(
                        R.current.mailShowImages,
                        style: context.text.bodyMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 信件裡有沒有指向外部的 `<img>`。
  ///
  /// 只看 http(s)：`cid:` 是信件自己夾帶的 part（connector 已經換成 `data:`），
  /// 顯示它不會對外發任何請求。
  static bool hasRemoteImages(String html) =>
      RegExp("""<img[^>]+src=[\\"']?https?://""", caseSensitive: false)
          .hasMatch(html);

  Widget _buildContent(MailContent content) {
    final html = content.html;
    final blocked = !_showRemoteImages && hasRemoteImages(html);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (content.attachments.isNotEmpty)
          _attachmentSection(content.attachments),
        if (blocked) _remoteImageCard(),
        Padding(
          // 內文左右不留白：圖片與表格可以撐滿整個寬度。純文字段落自己帶
          // 16px 內距是 HtmlWidget 做不到的，所以這裡整段給 16，只有需要
          // 滿版的信會自己超出去——那正是我們要的。
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: HtmlWidget(
            html,
            renderMode: RenderMode.column,
            // 不給 textStyle 的話會繼承到主題的 bodyMedium（行高 1.6）甚至
            // bodyLarge（1.7）——那是給清單與說明文字用的鬆度，整封信讀起來會
            // 散掉。1.5 與 Moodle 教材那一頁同一個值。
            textStyle: context.text.bodyMedium!
                .copyWith(height: 1.5, color: context.scheme.onSurface),
            factoryBuilder: Theme.of(context).brightness == Brightness.dark
                ? _mailHtmlWidgetFactoryDark
                : _mailHtmlWidgetFactory,
            // **接管圖片的載入指示。** 不給的話 fwfh 會畫它自己的
            // `CircularProgressIndicator.adaptive`（`core_widget_factory.dart`），
            // 那是 Material 預設的 4.0 粗線，跟 App 只有一種的 `TatProgress`
            // 明顯不同——畫面上會先後出現兩種長得不一樣的轉圈。
            onLoadingBuilder: MailDetailPage.imageLoadingBuilder,
            // **遠端圖片預設不載入。** 信件是不受信任的內容，那些 `<img>` 有
            // 相當比例是追蹤像素——載下去等於把「這封信被讀了、什麼時候讀的、
            // 從哪個 IP」回報給寄件者。使用者按了「顯示圖片」才放行，而且只
            // 放行這一次，不落盤：那等於把預設值悄悄改掉。
            customWidgetBuilder: (dom.Element element) {
              if (_showRemoteImages) return null;
              if (element.localName != 'img') return null;
              final src = element.attributes['src'] ?? '';
              if (src.startsWith('cid:') || src.startsWith('data:')) {
                return null;
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  /// 底部動作列：回覆是填色主鈕，全部回覆與轉寄縮成兩顆 tonal 鈕排在右邊，
  /// 順序照使用頻率。
  Widget _actionBar() {
    final scheme = context.scheme;
    return Material(
      color: context.tokens.card,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border:
                Border(top: BorderSide(color: scheme.outlineVariant, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => unawaited(_reply(all: false)),
                  icon: const Icon(LucideIcons.reply, size: 19),
                  label: Text(R.current.mailReply),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(TatTokens.heightButton),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(TatTokens.radiusButton),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _tonalAction(
                tooltip: R.current.mailReplyAll,
                icon: LucideIcons.replyAll,
                onPressed: () => unawaited(_reply(all: true)),
              ),
              const SizedBox(width: 8),
              _tonalAction(
                tooltip: R.current.mailForward,
                icon: LucideIcons.forward,
                onPressed: () => unawaited(_forward()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tonalAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) =>
      SizedBox(
        width: TatTokens.heightButton,
        height: TatTokens.heightButton,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 20, color: context.scheme.onSurfaceVariant),
          style: IconButton.styleFrom(
            backgroundColor: context.tokens.page,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TatTokens.radiusButton),
            ),
          ),
        ),
      );
}
