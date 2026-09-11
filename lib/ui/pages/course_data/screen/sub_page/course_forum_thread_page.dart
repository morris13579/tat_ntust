import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/course_data/course_forum_thread_controller.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/moodle_draft_url_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/page/web_view_opener.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_compose_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_rich_edit_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_attach_picker.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_bottom_bar.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_composer_bar.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_post_action_sheet.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_post_block.dart';
import 'package:flutter_app/ui/service/file_download.dart';
import 'package:get/get.dart';

/// 一則討論串：第一篇加上全部回覆。公告分頁與一般討論區都推這一頁——它們是
/// 同一種東西，只是討論區的 type 不同。
///
/// **回覆不換頁**：底部釘一條 [ForumComposerBar]，對話還在上面。只有編輯既有
/// 貼文才換頁（`CourseForumComposePage.edit`）。WebView 開啟器由呼叫端注入，
/// 見 docs/ARCHITECTURE.md「UI 慣例」。
class CourseForumThreadPage extends StatefulWidget {
  const CourseForumThreadPage(
    this.courseInfo, {
    required this.discussionId,
    required this.title,
    this.forumId = 0,
    this.fallbackDiscussion,
    this.readOnly = false,
    required this.onDiscussionChanged,
    required this.openWebView,
    super.key,
  });

  final CourseInfoJson courseInfo;

  /// `Discussions.discussion`，不是 `Discussions.id`——後者是第一篇貼文的 id。
  final int discussionId;

  /// AppBar 標題。HTML 實體已由 connector 還原。
  final String title;

  /// forum instance id。**只有附件政策要用它**；0（舊快取）時附件入口收起來，
  /// 回覆／編輯／刪除照常——那三件事都不需要 forum record。
  final int forumId;

  /// 抓不到回覆時的退路貼文來源：清單那一列本身就是第一篇貼文。從剛建立的
  /// 主題直接進來時手上沒有那一列，是 null。
  final Discussions? fallbackDiscussion;

  /// 唯讀的討論區（公告區）。學生在那裡本來就不能回覆，網頁版也一樣——所以
  /// 不畫「這裡不能回覆，去網頁」那條列：那句話的前提是「網頁還有路」。
  /// 老師手上的回覆列不受影響，那條分支在前面就先走掉了。
  final bool readOnly;

  /// 清單那一列已經不是伺服器上的樣子了：主文被刪掉，或第一篇被編輯過
  /// （`forum_discussions.name` 與附件旗標都會跟著變）。
  ///
  /// **刻意不是 pop 的回傳值**：回傳值只要有一個呼叫端忘了接就是靜默失效，
  /// 而且返回手勢與返回鍵各有各的路。注入一個 callback 讓每個呼叫端都得
  /// 決定要怎麼辦。
  final VoidCallback onDiscussionChanged;

  final WebViewOpener openWebView;

  @override
  State<StatefulWidget> createState() => _CourseForumThreadPageState();
}

class _CourseForumThreadPageState extends State<CourseForumThreadPage> {
  late final CourseForumThreadController _controller;

  /// AppBar 的標題。編輯第一篇會改掉主題名，那時它要跟著換——不然使用者剛
  /// 改完標題，頭上那一行還在說舊的。
  late String _title;
  final _scrollController = ScrollController();
  final _composerKey = GlobalKey<ForumComposerBarState>();

  /// 每一則貼文一把 key，依 id 沿用——整串重抓之後捲動位置不會亂。
  final _postKeys = <int, GlobalKey>{};

  /// 正在回覆哪一篇。null ＝第一篇（預設）。
  MoodleForumPost? _aimAt;

  /// 由 [ForumComposerBar] 回報，給這一頁的 `PopScope` 用。
  bool _hasDraft = false;
  bool _busy = false;

  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _controller = CourseForumThreadController(
      discussionId: widget.discussionId,
      courseId: widget.courseInfo.main.course.id,
      forumId: widget.forumId,
    );
    unawaited(_controller.loadPosts());
    unawaited(_controller.loadAttachPolicy());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 送出中一律擋住：那一則已經在路上了，離開只會讓它沒有人接。
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
        // 鍵盤打開時要把 body 讓出來——回覆列就住在 body 的最下面。
        resizeToAvoidBottomInset: true,
        appBar: baseAppbar(
          title: _title,
          onBack: () => Navigator.maybePop(context),
          action: [
            IconButton(
              tooltip: R.current.forumOpenInWeb,
              icon: const Icon(LucideIcons.externalLink, size: 18),
              onPressed: () => unawaited(_openInWeb()),
            ),
          ],
        ),
        // 回覆列是 body 的最後一格，**不是 `bottomNavigationBar`**：那個位置
        // 是照整個畫面的高度釘的，鍵盤一開就把它整條蓋住（那正是使用者回報
        // 的「打字看不到自己在打什麼」）。放進 body 之後
        // `resizeToAvoidBottomInset` 會把整欄抬到鍵盤上方，貼文自己讓出高度。
        body: Column(
          children: [
            Expanded(
              child: GestureDetector(
                // 討論串上的空白處收鍵盤。只包貼文那一段，不包回覆列——包進去
                // 的話點到列自己的留白就會把正在打的字關掉鍵盤。translucent 才
                // 收得到落在貼文之間空隙的點擊，而貼文自己的 InkWell 在手勢
                // 競技場裡比較深，照樣先贏。
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: ResultView<List<MoodleForumPost>>(
                  state: _controller.posts,
                  // **一定要 keepVisible**：這顆重試只出現在 `Stale` 的橫幅
                  // 上，也就是貼文與回覆列都還在畫面上的時候。清成 null 會把
                  // 回覆列整個拆掉，連同它 State 裡的草稿與已挑好的附件一起
                  // 消失。
                  onRetry: () => _controller.loadPosts(keepVisible: true),
                  errorBuilder: _fallback,
                  builder: _thread,
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  /// 抓不到回覆時至少把第一篇畫出來：清單那一列本身就是第一篇貼文。從剛建立
  /// 的主題進來時手上沒有那一列，就只畫錯誤與重試。
  Widget _fallback(String message) {
    final discussion = widget.fallbackDiscussion;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: [
        if (discussion != null) ...[
          _block(ThreadPost(MoodleForumUtils.rootPostOf(discussion), 0),
              first: true),
          const SizedBox(height: 12),
        ],
        InlineErrorView(message: message, onRetry: _controller.loadPosts),
      ],
    );
  }

  Widget _thread(List<MoodleForumPost> posts) {
    final items = MoodleForumUtils.buildThread(posts);
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      // 底部 padding 只留 12：底下是一條實體的列，不是空氣。
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _block(items[index], first: index == 0, posts: posts),
    );
  }

  Widget _block(ThreadPost item,
      {required bool first, List<MoodleForumPost> posts = const []}) {
    final p = item.post;
    return ForumPostBlock(
      key: _keyOf(p.id),
      item: item,
      first: first,
      aimed: _aimAt?.id == p.id,
      canReply: _canReply(p),
      hasOwnerActions: _canEdit(p) || _canDelete(p),
      onReply: () => _aim(p),
      onActions: () => unawaited(_postActions(p, posts)),
      onOpenFile: _download,
      openWebView: widget.openWebView,
      dirName: widget.courseInfo.main.course.name,
      title: _title,
    );
  }

  GlobalKey _keyOf(int postId) =>
      _postKeys.putIfAbsent(postId, () => GlobalKey());

  /// 三選一，永遠只有一個。
  ///
  /// 載入中與 `Failed` 都不畫列：能不能回覆來自 `capabilities`，貼文還沒到就
  /// 沒有可以瞄準的對象，畫一條按不動的列等於說謊。`Stale` 照畫——「送出成功
  /// 但重抓失敗」會停在那裡，那時使用者必須能繼續講話。
  Widget _bottomBar() => Obx(() {
        final result = _controller.posts.value;
        final posts = switch (result) {
          Ok<List<MoodleForumPost>>(:final data) => data,
          Stale<List<MoodleForumPost>>(:final data) => data,
          _ => null,
        };
        if (posts == null) return const SizedBox.shrink();
        if (!posts.any(_canReply)) {
          // 公告區的唯讀是常態，不是「App 走不通」：網頁版走的是同一個
          // `replynews`，那條列只會給一個一樣被拒的出口。
          if (widget.readOnly) return const SizedBox.shrink();
          return ForumNoticeBar(
            message: R.current.forumThreadLocked,
            onOpenWeb: () => unawaited(_openInWeb()),
          );
        }
        return ForumComposerBar(
          key: _composerKey,
          hintText: R.current.forumReplyHint,
          targetLabel: _aimAt == null ? null : _authorOf(_aimAt!),
          topicLabel: _title,
          canAttach: _controller.policy.enabled,
          maxAttachments: _controller.policy.maxFiles,
          maxBytes: _controller.policy.maxBytes,
          onPickFiles: _pickFiles,
          onSend: _send,
          onCancelUpload: () => _cancelToken?.cancel(),
          onAimAtRoot: () => setState(() => _aimAt = null),
          onScrollToTarget: () => _scrollTo(_targetPost?.id),
          onDraftChanged: _setHasDraft,
          onBusyChanged: (busy) => setState(() => _busy = busy),
        );
      });

  /// 回覆列被拿掉時會在 post-frame 回報一次 false，那時整頁可能已經走了；
  /// 沒有 `mounted` 這一格就會是 setState after dispose。
  void _setHasDraft(bool has) {
    if (!mounted || _hasDraft == has) return;
    setState(() => _hasDraft = has);
  }

  String _authorOf(MoodleForumPost p) {
    final name = p.author?.fullname ?? "";
    return name.isNotEmpty ? name : R.current.forumUnknownAuthor;
  }

  /// 瞄準某一篇：目標列出現、輸入框取得焦點、那一篇捲到列的上緣並加外框。
  void _aim(MoodleForumPost p) {
    setState(() => _aimAt = _rootPost?.id == p.id ? null : p);
    _composerKey.currentState?.focusInput();
    _scrollTo(p.id);
  }

  void _scrollTo(int? postId) {
    if (postId == null) return;
    final context = _keyOf(postId).currentContext;
    if (context == null) return;
    unawaited(Scrollable.ensureVisible(
      context,
      alignment: 0.1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    ));
  }

  MoodleForumPost? get _rootPost {
    final posts = _controller.posts.value?.dataOrNull;
    if (posts == null || posts.isEmpty) return null;
    for (final p in posts) {
      if (!p.hasparent) return p;
    }
    return posts.first;
  }

  /// 回覆的目標：使用者沒有指定時就是第一篇。
  MoodleForumPost? get _targetPost => _aimAt ?? _rootPost;

  Future<List<File>> _pickFiles(int remaining) =>
      pickForumAttachments(context, remaining: remaining);

  /// 送出一則回覆。true ＝成功（列自己清空）。
  Future<bool> _send(
    String text,
    List<File> files, {
    required void Function(ForumTransferProgress progress) onProgress,
  }) async {
    final parent = _targetPost;
    if (parent == null) return false;
    final token = CancelToken();
    _cancelToken = token;
    try {
      final result = await _controller.reply(
        postId: parent.id,
        subject: _replySubject(parent),
        text: text,
        attachments: files,
        policy: _controller.policy,
        onProgress: onProgress,
        cancelToken: token,
      );
      if (!mounted) return false;
      switch (result) {
        case Ok(:final data):
          await _afterReply(data);
          return true;
        case Stale(:final reason):
        case Failed(:final reason):
          // 留在原地，文字與附件原封不動。
          TaskUiDelegate.instance.toast(reason.message);
          return false;
      }
    } finally {
      _cancelToken = null;
    }
  }

  Future<void> _afterReply(ForumReplyOutcome outcome) async {
    setState(() => _aimAt = null);
    await _controller.appendPost(outcome.post);
    // 重抓是為了拿伺服器排好的順序與新的 capabilities；失敗時 controller 會
    // 退回 Stale，剛送出的那一則留在畫面上——寫入確實成功了。
    await _controller.loadPosts(keepVisible: true);
    if (!mounted) return;
    // 回覆路徑不吐「已送出」：那則回覆就在眼前。
    if (_controller.posts.value is Stale<List<MoodleForumPost>>) {
      TaskUiDelegate.instance.toast(R.current.forumSendDoneRefreshFailed);
    }
    // 附件被伺服器靜靜丟掉時另外說一句：貼文真的發出去了，不可以報成失敗，
    // 也不可以裝作全部都上去了。
    final warning = outcome.warning;
    if (warning != null) TaskUiDelegate.instance.toast(warning);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollTo(outcome.post.id));
  }

  Future<void> _postActions(
      MoodleForumPost p, List<MoodleForumPost> posts) async {
    final action = await showForumPostActionSheet(
      context,
      canEdit: _canEdit(p),
      canDelete: _canDelete(p),
      deleteBlockedByReplies:
          MoodleForumEditUtils.hasVisibleReplies(posts, p.id),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case ForumPostAction.edit:
        await _startEdit(p);
      case ForumPostAction.delete:
        await _confirmDelete(p);
    }
  }

  /// 編輯的守門（最容易做壞的一格）。
  ///
  /// 一定要先打一趟 `mod_forum_get_discussion_post`：畫面上的
  /// `capabilities.edit` 是抓取當下的快照，而編輯窗長度讀不到；而且編輯頁要
  /// 填的是**原文**，快取裡只有算繪好的 HTML。
  Future<void> _startEdit(MoodleForumPost p) async {
    final fresh = await _controller.loadPostForEdit(p.id);
    if (!mounted) return;
    if (fresh == null) {
      TaskUiDelegate.instance.toast(R.current.forumEditError);
      return;
    }
    if (!fresh.canEdit) {
      // 不提網頁：網頁版走同一個 can_edit_post，一樣過期了。
      TaskUiDelegate.instance.toast(R.current.forumEditWindowClosed);
      await _controller.loadPosts(keepVisible: true);
      return;
    }
    if (!mounted) return;
    final isTopicPost = !p.hasparent;
    switch (
        MoodleForumEditUtils.editorKindFor(fresh.rawMessage, fresh.rawFormat)) {
      // 排版或內嵌圖片撐不進純文字框 → 所見即所得。內嵌檔案的對照表只有
      // 討論串上那一篇有：`getPostForEdit` 刻意不帶
      // `includeinlineattachments`，它的 `messageinlinefiles` 永遠是空的。
      case ForumEditorKind.rich:
        await _startRichEdit(p, fresh, isTopicPost: isTopicPost);
      case ForumEditorKind.plainText:
        await _startPlainEdit(p, fresh, isTopicPost: isTopicPost);
      // 框裡是原始碼，不是還原出來的純文字：那一行說明也要跟著換，否則畫面會
      // 叫使用者去網頁版做一件他現在就做得到的事。
      case ForumEditorKind.rawSource:
        await _startPlainEdit(p, fresh,
            isTopicPost: isTopicPost,
            formattingNote: fresh.rawFormat == MoodleForumUtils.formatMarkdown
                ? R.current.forumMarkdownSource
                : R.current.forumRawSourceEdit);
    }
  }

  /// 純文字框那條路。**預填的字一定要走 [MoodleForumEditUtils.initialTextFor]**：
  /// 無條件套 `htmlToPlain` 會把 FORMAT_PLAIN 貼文裡真的打出來的 `a &amp; b`
  /// 悄悄改成 `a & b`，而 `plainEditPayload` 對非 HTML 是原樣送回。
  Future<void> _startPlainEdit(MoodleForumPost p, ForumPostEdit fresh,
      {required bool isTopicPost, String? formattingNote}) async {
    final outcome = await Get.to<ForumEditOutcome>(
      () => CourseForumComposePage.edit(
        postId: p.id,
        isTopicPost: isTopicPost,
        initialSubject: fresh.subject,
        initialText: MoodleForumEditUtils.initialTextFor(
            fresh.rawMessage, fresh.rawFormat),
        existingAttachments: fresh.attachments,
        // 每一次送出都是一把新的 token。`??=` 會把使用者取消過的那一把一直
        // 遞回去，而 dio 對已取消的 token 是在送出之前就直接丟——重試永遠
        // 不可能成功，人就困在一頁按不動的編輯器上。
        onSendEdit: (subject, text, keep, added, {required onProgress}) async {
          final token = CancelToken();
          _cancelToken = token;
          try {
            return await _controller.editPost(
              postId: p.id,
              subject: subject,
              text: text,
              rawFormat: fresh.rawFormat,
              keepAttachments: keep,
              newAttachments: added,
              hadAttachments: fresh.attachments.isNotEmpty,
              policy: _editAttachPolicy,
              onProgress: onProgress,
              cancelToken: token,
            );
          } finally {
            _cancelToken = null;
          }
        },
        attachPolicy: _editAttachPolicy,
        onPickFiles: _pickFiles,
        onCancelUpload: () => _cancelToken?.cancel(),
        onOpenAttachment: (f) async => _download(f),
        openWebView: widget.openWebView,
        webUrl: _discussionUrl(),
        webTitle: _title,
        formattingNote: formattingNote,
      ),
    );
    await _afterEdit(outcome, isTopicPost: isTopicPost);
  }

  /// 所見即所得那條路。編輯器裡看到的網址必須是**當下就載得動**的：先把
  /// `@@PLUGINFILE@@` 展開成真網址，再逐一換成帶憑證的版本。頁面本身不做這
  /// 兩件事，它只收一段 HTML。
  ///
  /// [p] 的 `messageinlinefiles` 是對照表的唯一來源——`getPostForEdit` 那一趟
  /// 刻意不帶 `includeinlineattachments`，它回的永遠是空陣列。
  Future<void> _startRichEdit(MoodleForumPost p, ForumPostEdit fresh,
      {required bool isTopicPost}) async {
    final inlineFiles = p.messageinlinefiles;
    final html = MoodleDraftUrlUtils.rewriteInlineUrlsForDisplay(
      MoodleForumUtils.resolveInlinePluginFiles(fresh.rawMessage, inlineFiles),
      inlineFiles,
      MoodleWebApiConnector.fileUrlWithToken,
    );
    final outcome = await Get.to<ForumEditOutcome>(
      () => CourseForumRichEditPage(
        postId: p.id,
        isTopicPost: isTopicPost,
        initialSubject: fresh.subject,
        initialHtml: html,
        existingAttachments: fresh.attachments,
        // 每一次送出都是一把新的 token，理由同 [_startPlainEdit]。
        onSend: (subject, editedHtml, keep, added,
            {required onProgress}) async {
          final token = CancelToken();
          _cancelToken = token;
          try {
            return await _controller.editPost(
              postId: p.id,
              subject: subject,
              // 純文字那一格在這條路上用不到，但 repository 的空內容守門要
              // 看得到東西，所以帶同一份 HTML 進去。
              text: editedHtml,
              rawFormat: fresh.rawFormat,
              keepAttachments: keep,
              newAttachments: added,
              hadAttachments: fresh.attachments.isNotEmpty,
              inlineHtml: editedHtml,
              inlineFiles: inlineFiles,
              policy: _editAttachPolicy,
              onProgress: onProgress,
              cancelToken: token,
            );
          } finally {
            _cancelToken = null;
          }
        },
        attachPolicy: _editAttachPolicy,
        onPickFiles: _pickFiles,
        onCancelUpload: () => _cancelToken?.cancel(),
        onOpenAttachment: (f) async => _download(f),
      ),
    );
    await _afterEdit(outcome, isTopicPost: isTopicPost);
  }

  /// 兩種編輯器共用的收尾。
  Future<void> _afterEdit(ForumEditOutcome? outcome,
      {required bool isTopicPost}) async {
    if (outcome == null || !mounted) return;
    // 回傳裡沒有更新後的貼文，所以一定要重讀伺服器。
    await _controller.loadPosts(keepVisible: true);
    if (!mounted) return;
    if (isTopicPost) {
      // 編輯第一篇會連帶改掉 `forum_discussions.name` 與附件旗標：清單那一列
      // 的標題與迴紋針都已經不對了，頭上這一行也是。標題取伺服器重讀回來的
      // 那一份，重抓失敗（Stale）時寧可留著舊的，也不要換成空字串。
      final subject = _rootPost?.subject ?? '';
      if (subject.isNotEmpty) setState(() => _title = subject);
      widget.onDiscussionChanged();
    }
    TaskUiDelegate.instance.toast(R.current.forumEditDone);
    final warning = outcome.warning;
    if (warning != null) TaskUiDelegate.instance.toast(warning);
  }

  /// 站台沒開 `prepare_draft_area_for_post` 時附件區收起來：沒有它就沒有辦法
  /// 種一個含既有附件的 draft 區。**原本就有附件的貼文連編輯入口都不會有**
  /// （見 [_canEdit]），走到這裡的一定是原本沒有附件的那些。
  ForumAttachPolicy get _editAttachPolicy =>
      MoodleWebApiConnector.canPrepareForumDraftArea
          ? _controller.policy
          : const ForumAttachPolicy.off();

  Future<void> _confirmDelete(MoodleForumPost p) async {
    final isTopicPost = !p.hasparent;
    final confirmed = await showTatDialog<bool>(
      dialog: TatDialog(
        // 主文的刪除會連同整串一起消失——Moodle 的行為，不可以用同一句話騙人。
        title: isTopicPost
            ? R.current.forumDeleteTopicConfirm
            : R.current.forumDeletePostConfirm,
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
    if (confirmed != true || !mounted) return;
    final result =
        await _controller.deletePost(postId: p.id, isTopicPost: isTopicPost);
    if (!mounted) return;
    switch (result) {
      case Ok():
        TaskUiDelegate.instance.toast(R.current.forumDeleteDone);
        if (isTopicPost) {
          // 討論串已經不存在，**不可以**再打 get_discussion_posts：伺服器端
          // 那一支沒有 null 檢查，會丟 PHP Error 而看起來像刪除失敗。
          widget.onDiscussionChanged();
          Get.back();
          return;
        }
        await _controller.removePost(p.id);
        // 不樂觀地把那一列拿掉當作結論：Moodle 對有子貼文的貼文是換成墓碑
        // 而不是刪除，伺服器說了算。
        await _controller.loadPosts(keepVisible: true);
      case Stale(:final reason):
      case Failed(:final reason):
        TaskUiDelegate.instance.toast(reason.message);
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

  void _download(MoodleForumFile f) => unawaited(FileDownload.download(
        context,
        MoodleWebApiConnector.fileUrlWithToken(f.url),
        widget.courseInfo.main.course.name,
        name: f.filename,
      ));

  Future<void> _openInWeb() => widget.openWebView(_title, _discussionUrl());

  /// 網頁版討論串。這裡不呼叫 `autologinUrl`：注入的 [CourseForumThreadPage
  /// .openWebView] 自己會換，再換一次等於在六分鐘的伺服器節流內多燒一把鑰匙。
  String _discussionUrl() => Connector.uriAddQuery(
        "${MoodleWebApiConnector.host}/mod/forum/discuss.php"
        "?d=${widget.discussionId}",
        {"lang": LanguageUtils.getLangIndex() == LangEnum.zh ? "zh_tw" : "en"},
      );

  /// 伺服器組好的「回覆: …」，語系跟著站台；沒有就退回討論串標題。
  String _replySubject(MoodleForumPost parent) =>
      parent.replysubject.isNotEmpty ? parent.replysubject : _title;

  /// 伺服器算的 `capabilities.reply` 是唯一判準（**不是** `urls.reply`：
  /// `selfenrol` 會讓那個網址在不能回覆時也非 null）；站台沒開放這支
  /// function 時整排都不畫。
  bool _canReply(MoodleForumPost p) =>
      MoodleForumUtils.canReply(p) && MoodleWebApiConnector.canPostToForum;

  /// 編輯與刪除的閘門。缺席 ＝ null ＝ 不知道 ＝ 不畫（照抄 `canReply` 的態度）。
  ///
  /// `_controller.fresh` 那一項是 0-a：能力旗標是抓取當下的快照，而編輯窗長度
  /// 讀不到，`Stale`（快取／離線／送出後重抓失敗）時它們就開始說謊。
  bool _canEdit(MoodleForumPost p) =>
      _controller.fresh &&
      MoodleWebApiConnector.canEditForumPost &&
      MoodleWebApiConnector.canReadForumPost &&
      p.capabilities?.edit == true &&
      !p.isdeleted &&
      // 有附件而站台沒開 `prepare_draft_area_for_post` 時整個不給編輯：那條路
      // 只剩「不送 attachmentsid」，而那會把主題清單的迴紋針清掉。與其在存檔
      // 那一刻才拒絕，不如一開始就不給入口。
      (p.attachments.isEmpty || MoodleWebApiConnector.canPrepareForumDraftArea);

  bool _canDelete(MoodleForumPost p) =>
      _controller.fresh &&
      MoodleWebApiConnector.canDeleteForumPost &&
      p.capabilities?.delete == true &&
      !p.isdeleted;
}
