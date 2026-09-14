import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/course_data/course_forum_thread_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/native/bridge_results.dart';
import 'package:flutter_app/src/native/moodle_memo.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/file_icon_utils.dart';
import 'package:flutter_app/src/util/forum_attachment_checks.dart';
import 'package:flutter_app/src/util/forum_feed_utils.dart';
import 'package:flutter_app/src/util/moodle_draft_url_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_app/src/util/rich_editor_bridge_utils.dart';
import 'package:sprintf/sprintf.dart';

/// 原生版的討論串：貼文、回覆、編輯、刪除。規則照 `CourseForumThreadController` 與
/// `course_forum_thread_page.dart`；貼文清單與附件政策住在這裡。
class ForumBridge implements TatForumApi {
  ForumBridge(this._memo, {void Function(TransferProgress progress)? onProgress})
      : _onProgress = onProgress ?? TatTransferHost().onProgress;

  static void install(MoodleMemo memo) => TatForumApi.setUp(ForumBridge(memo));

  final MoodleMemo _memo;
  final void Function(TransferProgress progress) _onProgress;
  final Map<int, _Thread> _threads = {};

  @override
  Future<ForumThread> thread(String courseId, int forumId, int discussionId,
      String title, bool readOnly, bool refresh) async {
    final existing = _threads[discussionId];
    final session = existing ??
        _Thread(
          CourseForumThreadController(
              discussionId: discussionId, courseId: courseId, forumId: forumId),
          title: title,
          readOnly: readOnly,
        );
    _threads[discussionId] = session;
    final c = session.controller;
    await Future.wait([
      // 重新整理時已經在畫面上的貼文不丟：清成 null 會讓整串變成轉圈再長回來。
      if (refresh || c.posts.value == null) c.loadPosts(keepVisible: refresh),
      if (c.attachPolicy.value == null) c.loadAttachPolicy(),
    ]);
    return _threadOf(session);
  }

  @override
  Future<AttachmentCheck> checkAttachments(
      int discussionId, List<String> existingNames, List<String> paths) async {
    final policy = _threads[discussionId]?.controller.policy ??
        const ForumAttachPolicy.off();
    final checked = await ForumAttachmentChecks.check(
      existingNames: existingNames,
      picked: [for (final path in paths) File(path)],
      policy: policy,
    );
    return AttachmentCheck(
      accepted: [for (final f in checked.accepted) f.path],
      messages: checked.messages,
    );
  }

  @override
  Future<ForumSendResult> reply(
      int discussionId, int? parentId, String text, List<String> paths) async {
    final session = _threads[discussionId];
    final posts = session?.controller.posts.value?.dataOrNull;
    final parent = posts == null
        ? null
        : (parentId == null ? _rootOf(posts) : _find(posts, parentId));
    if (session == null || parent == null) return _notSent(const []);
    final c = session.controller;
    final token = CancelToken();
    session.cancelToken = token;
    try {
      final result = await c.reply(
        postId: parent.id,
        // 伺服器組好的「回覆: …」，語系跟著站台；沒有就退回討論串標題。
        subject: parent.replysubject.isNotEmpty
            ? parent.replysubject
            : session.title,
        text: text.trim(),
        attachments: [for (final path in paths) File(path)],
        policy: c.policy,
        onProgress: (p) => _report(discussionId, p),
        cancelToken: token,
      );
      switch (result) {
        case Ok(:final data):
          await c.appendPost(data.post);
          // 重抓是為了伺服器排好的順序與新的 capabilities；失敗時退回 Stale，
          // 剛送出的那一則留在畫面上——寫入確實成功了。
          await c.loadPosts(keepVisible: true);
          return ForumSendResult(
            ok: true,
            messages: [
              if (c.posts.value is Stale<List<MoodleForumPost>>)
                R.current.forumSendDoneRefreshFailed,
              if (data.warning != null) data.warning!,
            ],
            thread: _threadOf(session),
            scrollTo: data.post.id,
            listChanged: false,
          );
        case Stale(:final reason):
        case Failed(:final reason):
          return _notSent([reason.message]);
      }
    } finally {
      session.cancelToken = null;
    }
  }

  @override
  Future<ForumEditStart> startEdit(int discussionId, int postId) async {
    final session = _threads[discussionId];
    final post = _find(session?.controller.posts.value?.dataOrNull ?? const [],
        postId);
    if (session == null || post == null) {
      return ForumEditStart(message: R.current.forumEditError);
    }
    final c = session.controller;
    // 一定要先打一趟：畫面上的 `capabilities.edit` 是抓取當下的快照，而編輯窗
    // 長度讀不到；編輯頁要填的是原文，快取裡只有算繪好的 HTML。
    final fresh = await c.loadPostForEdit(postId);
    if (fresh == null) return ForumEditStart(message: R.current.forumEditError);
    if (!fresh.canEdit) {
      await c.loadPosts(keepVisible: true);
      return ForumEditStart(
          message: R.current.forumEditWindowClosed, thread: _threadOf(session));
    }
    final kind =
        MoodleForumEditUtils.editorKindFor(fresh.rawMessage, fresh.rawFormat);
    // 內嵌檔案的對照表只有討論串上那一篇有：`getPostForEdit` 刻意不帶
    // `includeinlineattachments`，它的 `messageinlinefiles` 永遠是空的。
    session.edits[postId] = (fresh: fresh, inline: post.messageinlinefiles);
    final policy = _editPolicy(c);
    return ForumEditStart(
      draft: ForumEditDraft(
        postId: postId,
        isTopicPost: !post.hasparent,
        mode: switch (kind) {
          ForumEditorKind.plainText => ForumEditorMode.plain,
          ForumEditorKind.rawSource => ForumEditorMode.rawSource,
          ForumEditorKind.rich => ForumEditorMode.rich,
        },
        subject: fresh.subject,
        text: kind == ForumEditorKind.rich
            ? null
            : MoodleForumEditUtils.initialTextFor(
                fresh.rawMessage, fresh.rawFormat),
        // 編輯器裡看到的網址必須是當下就載得動的：先把 `@@PLUGINFILE@@` 展開成
        // 真網址，再逐一換成帶憑證的版本。
        editorScript: kind == ForumEditorKind.rich
            ? RichEditorBridgeUtils.buildSetContentCall(
                MoodleDraftUrlUtils.rewriteInlineUrlsForDisplay(
                  MoodleForumUtils.resolveInlinePluginFiles(
                      fresh.rawMessage, post.messageinlinefiles),
                  post.messageinlinefiles,
                  MoodleWebApiConnector.fileUrlWithToken,
                ))
            : null,
        // 框裡是原始碼時那一行說明要跟著換，否則畫面會叫使用者去網頁版做一件
        // 他現在就做得到的事。
        note: switch (kind) {
          ForumEditorKind.plainText => R.current.forumFormattingInWeb,
          ForumEditorKind.rawSource =>
            fresh.rawFormat == MoodleForumUtils.formatMarkdown
                ? R.current.forumMarkdownSource
                : R.current.forumRawSourceEdit,
          ForumEditorKind.rich => null,
        },
        attachments: [for (final f in fresh.attachments) _file(f)],
        attach: _rules(policy),
      ),
    );
  }

  @override
  Future<ForumSendResult> saveEdit(int discussionId, int postId, String subject,
      String text, List<String> keepNames, List<String> paths) async {
    final session = _threads[discussionId];
    final edit = session?.edits[postId];
    final post = _find(session?.controller.posts.value?.dataOrNull ?? const [],
        postId);
    if (session == null || edit == null || post == null) {
      return _notSent([R.current.forumEditError]);
    }
    final c = session.controller;
    final rich =
        MoodleForumEditUtils.editorKindFor(edit.fresh.rawMessage, edit.fresh.rawFormat) ==
            ForumEditorKind.rich;
    final token = CancelToken();
    session.cancelToken = token;
    try {
      final result = await c.editPost(
        postId: postId,
        subject: subject.trim(),
        // 所見即所得那條路用不到純文字那一格，但 repository 的空內容守門要看得到
        // 東西，所以帶同一份 HTML 進去。
        text: rich ? text : text.trim(),
        rawFormat: edit.fresh.rawFormat,
        keepAttachments: [
          for (final f in edit.fresh.attachments)
            if (keepNames.contains(f.filename)) f,
        ],
        newAttachments: [for (final path in paths) File(path)],
        hadAttachments: edit.fresh.attachments.isNotEmpty,
        inlineHtml: rich ? text : null,
        inlineFiles: rich ? edit.inline : const [],
        policy: _editPolicy(c),
        onProgress: (p) => _report(discussionId, p),
        cancelToken: token,
      );
      switch (result) {
        case Ok(:final data):
          session.edits.remove(postId);
          // 回傳裡沒有更新後的貼文，所以一定要重讀伺服器。
          await c.loadPosts(keepVisible: true);
          final isTopic = !post.hasparent;
          if (isTopic) {
            // 標題取伺服器重讀回來的那一份；重抓失敗時寧可留著舊的，也不要換成空字串。
            final fresh = _rootOf(c.posts.value?.dataOrNull ?? const []);
            if ((fresh?.subject ?? '').isNotEmpty) session.title = fresh!.subject;
          }
          return ForumSendResult(
            ok: true,
            messages: [
              R.current.forumEditDone,
              if (data.warning != null) data.warning!,
            ],
            thread: _threadOf(session),
            listChanged: isTopic,
          );
        case Stale(:final reason):
        case Failed(:final reason):
          return _notSent([reason.message]);
      }
    } finally {
      session.cancelToken = null;
    }
  }

  @override
  Future<ForumDeleteResult> deletePost(int discussionId, int postId) async {
    final session = _threads[discussionId];
    final post = _find(session?.controller.posts.value?.dataOrNull ?? const [],
        postId);
    if (session == null || post == null) {
      return ForumDeleteResult(
          messages: [R.current.forumDeleteError], closeThread: false);
    }
    final c = session.controller;
    final isTopic = !post.hasparent;
    final result = await c.deletePost(postId: postId, isTopicPost: isTopic);
    switch (result) {
      case Ok():
        if (isTopic) {
          // 討論串已經不存在，不可以再打 get_discussion_posts：伺服器那一支沒有
          // null 檢查，會丟 PHP Error 而看起來像刪除失敗。
          _threads.remove(discussionId)?.controller.dispose();
          return ForumDeleteResult(
              messages: [R.current.forumDeleteDone], closeThread: true);
        }
        await c.removePost(postId);
        // 不樂觀地把那一列拿掉當作結論：有子貼文的貼文是換成墓碑而不是刪除，伺服器說了算。
        await c.loadPosts(keepVisible: true);
        return ForumDeleteResult(
          messages: [R.current.forumDeleteDone],
          closeThread: false,
          thread: _threadOf(session),
        );
      case Stale(:final reason):
      case Failed(:final reason):
        return ForumDeleteResult(messages: [reason.message], closeThread: false);
    }
  }

  @override
  void cancelTransfer(int discussionId) =>
      _threads[discussionId]?.cancelToken?.cancel();

  ForumThread _threadOf(_Thread session) {
    final c = session.controller;
    final result = c.posts.value;
    final posts = switch (result) {
      Ok(:final data) => data,
      Stale(:final data) => data,
      _ => null,
    };
    final rules = _rules(c.policy);
    if (posts == null) {
      // 抓不到回覆時至少把第一篇畫出來：清單那一列本身就是第一篇貼文。
      final fallback = _memo.discussions[c.discussionId];
      return ForumThread(
        title: session.title,
        posts: [
          if (fallback != null)
            _post(ThreadPost(MoodleForumUtils.rootPostOf(fallback), 0), c,
                const []),
        ],
        composer: ForumComposerMode.hidden,
        attach: rules,
        error: result == null ? null : BridgeResults.errorOf(result),
        signedIn: AuthSession.instance.isSignedIn,
      );
    }
    final api = _api;
    final canReplyAny =
        posts.any((p) => MoodleForumEditUtils.canReplyTo(p, api: api));
    return ForumThread(
      title: session.title,
      posts: [
        for (final item in MoodleForumUtils.buildThread(posts))
          _post(item, c, posts),
      ],
      // 公告區的唯讀是常態：網頁版走的是同一個 `replynews`，那條列只會給一個一樣被拒的出口。
      composer: canReplyAny
          ? ForumComposerMode.reply
          : (session.readOnly
              ? ForumComposerMode.hidden
              : ForumComposerMode.locked),
      attach: rules,
      notice: result == null ? null : BridgeResults.noticeOf(result),
      signedIn: AuthSession.instance.isSignedIn,
    );
  }

  ForumPostItem _post(ThreadPost item, CourseForumThreadController c,
      List<MoodleForumPost> posts) {
    final p = item.post;
    final author = p.author?.fullname ?? '';
    final name = author.isNotEmpty ? author : R.current.forumUnknownAuthor;
    final empty = p.message.trim().isEmpty;
    final api = _api;
    return ForumPostItem(
      id: p.id,
      depth: item.depth,
      author: name,
      initial: forumInitialOf(name),
      time: forumPostTimeLabel(p),
      // 只有第一篇印標題：回覆的 subject 是伺服器語系的「回覆: …」，重複又難看。
      subject: item.depth == 0 && p.subject.isNotEmpty ? p.subject : null,
      messageHtml: p.isdeleted || empty ? null : p.message,
      placeholder: p.isdeleted
          ? R.current.forumPostDeleted
          : (empty ? R.current.nothingHere : null),
      deleted: p.isdeleted,
      attachments: [for (final f in p.attachments) _file(f)],
      canReply: MoodleForumEditUtils.canReplyTo(p, api: api),
      canEdit: MoodleForumEditUtils.canEditPost(p, fresh: c.fresh, api: api),
      canDelete:
          MoodleForumEditUtils.canDeletePost(p, fresh: c.fresh, api: api),
      hasReplies: MoodleForumEditUtils.hasVisibleReplies(posts, p.id),
    );
  }

  static ForumApiAvailability get _api => (
        canPost: MoodleWebApiConnector.canPostToForum,
        canEdit: MoodleWebApiConnector.canEditForumPost,
        canRead: MoodleWebApiConnector.canReadForumPost,
        canDelete: MoodleWebApiConnector.canDeleteForumPost,
        canPrepareDraft: MoodleWebApiConnector.canPrepareForumDraftArea,
      );

  /// 站台沒開 `prepare_draft_area_for_post` 時附件區收起來：沒有它就種不出一個含既有附件的 draft 區。
  static ForumAttachPolicy _editPolicy(CourseForumThreadController c) =>
      MoodleWebApiConnector.canPrepareForumDraftArea
          ? c.policy
          : const ForumAttachPolicy.off();

  static ForumAttachRules _rules(ForumAttachPolicy policy) => ForumAttachRules(
        enabled: policy.enabled,
        maxFiles: policy.maxFiles,
        hint: policy.enabled ? ForumAttachmentChecks.hint(policy) : '',
      );

  static MoodleFileRow _file(MoodleForumFile f) => MoodleFileRow(
        name: f.filename,
        fileIcon: FileIconUtils.iconFor(filename: f.filename),
        url: MoodleWebApiConnector.fileUrlWithToken(f.url),
      );

  static ForumSendResult _notSent(List<String> messages) =>
      ForumSendResult(ok: false, messages: messages, listChanged: false);

  static MoodleForumPost? _find(List<MoodleForumPost> posts, int id) {
    for (final p in posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 第一篇：沒有父貼文的那一則；找不到就是清單上的第一則。
  static MoodleForumPost? _rootOf(List<MoodleForumPost> posts) {
    if (posts.isEmpty) return null;
    for (final p in posts) {
      if (!p.hasparent) return p;
    }
    return posts.first;
  }

  void _report(int discussionId, ForumTransferProgress progress) {
    final uploading = progress.phase == ForumTransferPhase.upload;
    final name = progress.filename;
    _onProgress(TransferProgress(
      key: 'forum-$discussionId',
      progress: uploading ? progress.overall : null,
      label: uploading && name != null
          ? sprintf(R.current.assignUploadingFile, [name])
          : R.current.forumSending,
      phase: uploading ? TransferPhase.upload : TransferPhase.posting,
    ));
  }
}

class _Thread {
  _Thread(this.controller, {required this.title, required this.readOnly});

  final CourseForumThreadController controller;

  /// 編輯第一篇會改掉主題名，那時它要跟著換。
  String title;
  final bool readOnly;
  CancelToken? cancelToken;
  final Map<int, ({ForumPostEdit fresh, List<MoodleForumFile> inline})> edits =
      {};
}
