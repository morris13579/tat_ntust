import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/native/forum_bridge.dart';
import 'package:flutter_app/src/native/moodle_memo.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeMoodle extends MoodleRepository {
  Result<List<MoodleForumPost>> posts = const Failed(FetchFailed());
  Result<ForumAttachPolicy> policy = const Ok(ForumAttachPolicy.off());
  Result<ForumReplyOutcome> replyResult = const Failed(FetchFailed());
  ForumPostEdit? postForEdit;
  Result<ForumEditOutcome> editResult = const Failed(FetchFailed());
  Result<bool> deleteResult = const Failed(FetchFailed());
  ({int postId, String subject, String text, int files})? lastReply;

  @override
  Future<Result<List<MoodleForumPost>>> getDiscussionPosts(
          int discussionId) async =>
      posts;

  @override
  Future<Result<ForumAttachPolicy>> getForumAttachPolicy(
          {required String courseId, required int forumId}) async =>
      policy;

  @override
  Future<Result<ForumReplyOutcome>> postReply({
    required int postId,
    required String subject,
    required String text,
    List<File> attachments = const [],
    ForumAttachPolicy policy = const ForumAttachPolicy.off(),
    void Function(ForumTransferProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    lastReply = (
      postId: postId,
      subject: subject,
      text: text,
      files: attachments.length
    );
    onProgress?.call(const ForumTransferProgress(
        done: 0,
        total: 1,
        ratio: 0.5,
        phase: ForumTransferPhase.upload,
        filename: 'a.png'));
    return replyResult;
  }

  @override
  Future<ForumPostEdit?> fetchPostForEdit(int postId) async => postForEdit;

  @override
  Future<Result<ForumEditOutcome>> editPost({
    required int postId,
    required String subject,
    required String text,
    required int rawFormat,
    required List<MoodleForumFile> keepAttachments,
    required List<File> newAttachments,
    required bool hadAttachments,
    String? inlineHtml,
    List<MoodleForumFile> inlineFiles = const [],
    ForumAttachPolicy policy = const ForumAttachPolicy.off(),
    void Function(ForumTransferProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async =>
      editResult;

  @override
  Future<Result<bool>> deletePost(
          {required int postId,
          required bool isTopicPost,
          required int discussionId}) async =>
      deleteResult;
}

MoodleForumPost post(
  int id, {
  int? parent,
  bool reply = true,
  bool edit = false,
  bool delete = false,
  String subject = '期中考範圍',
  String message = '<p>內容</p>',
}) =>
    MoodleForumPost(
      id: id,
      subject: parent == null ? subject : '回覆: $subject',
      message: message,
      replysubject: '回覆: $subject',
      capabilities:
          MoodleForumPostCapabilities(reply: reply, edit: edit, delete: delete),
      author: MoodleForumAuthor(fullname: parent == null ? '王老師' : '李大華'),
      discussionid: 9,
      hasparent: parent != null,
      parentid: parent,
      timecreated: 1700000000,
      timemodified: 1700000000,
    );

/// 原生版的討論串。回覆掛在哪一篇底下、什麼時候給回覆列、編輯開哪一種編輯器、刪了第一篇要不要回清單，
/// 都是 Dart 的判斷——壞了，原生版會把回覆掛錯篇，或拿過期的權限讓人改一篇已經不能改的貼文。
void main() {
  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  late _FakeMoodle moodle;
  late MoodleMemo memo;
  late ForumBridge bridge;
  late List<TransferProgress> progress;

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    moodle = _FakeMoodle();
    MoodleRepository.instance = moodle;
    memo = MoodleMemo();
    progress = [];
    bridge = ForumBridge(memo, onProgress: progress.add);
  });

  tearDown(() => MoodleRepository.instance = MoodleRepository());

  Future<ForumThread> open({int discussionId = 9, bool readOnly = false}) =>
      bridge.thread('CS1', 5, discussionId, '期中考範圍', readOnly, false);

  group('討論串', () {
    test('回覆掛在父貼文底下；只有第一篇印標題；有人能回覆就給回覆列；附件政策照伺服器', () async {
      moodle.posts = Ok([post(1), post(3, parent: 2), post(2, parent: 1)]);
      moodle.policy = const Ok(
          ForumAttachPolicy(enabled: true, maxFiles: 3, maxBytes: 0));

      final thread = await open();

      expect(thread.posts.map((p) => (p.id, p.depth)), [(1, 0), (2, 1), (3, 2)]);
      expect(thread.posts.first.subject, '期中考範圍');
      expect(thread.posts[1].subject, isNull);
      expect(thread.posts.first.initial, '王');
      expect(thread.composer, ForumComposerMode.reply);
      expect(thread.attach.enabled, isTrue);
      expect(thread.attach.maxFiles, 3);
      expect(thread.attach.hint, '最多 3 個檔案');
    });

    test('沒有人能回覆：公告區什麼都不畫，一般討論區說明鎖住了', () async {
      moodle.posts = Ok([post(1, reply: false)]);

      expect((await open(readOnly: true)).composer, ForumComposerMode.hidden);
      expect((await open(discussionId: 10)).composer, ForumComposerMode.locked);
    });

    test('抓不到回覆：至少把清單上那一列當第一篇畫出來，並帶著原因', () async {
      memo.discussions[9] = Discussions(
        id: 1,
        discussion: 9,
        name: '期中考範圍',
        subject: '期中考範圍',
        message: '<p>公告</p>',
        userfullname: '王老師',
        created: 1700000000,
      );
      moodle.posts = const Failed(FetchFailed('抓不到'));

      final thread = await open();

      expect(thread.posts.single.messageHtml, '<p>公告</p>');
      expect(thread.error, '抓不到');
      expect(thread.composer, ForumComposerMode.hidden);
    });
  });

  group('回覆', () {
    test('預設回第一篇，標題用伺服器組好的；成功後捲到新的那一則並回報上傳進度', () async {
      moodle.posts = Ok([post(1)]);
      await open();
      final added = post(4, parent: 1);
      moodle.replyResult = Ok(ForumReplyOutcome(added));
      moodle.posts = Ok([post(1), added]);

      final result = await bridge.reply(9, null, '  我也想問  ', const []);

      expect(moodle.lastReply,
          (postId: 1, subject: '回覆: 期中考範圍', text: '我也想問', files: 0));
      expect(result.ok, isTrue);
      expect(result.scrollTo, 4);
      expect(result.thread?.posts.map((p) => p.id), [1, 4]);
      expect(progress.single.key, 'forum-9');
      expect(progress.single.label, '正在上傳 a.png');
    });

    test('送不出去：留在原地，理由原樣給', () async {
      moodle.posts = Ok([post(1)]);
      await open();
      moodle.replyResult = const Failed(FetchFailed('送出失敗'));

      final result = await bridge.reply(9, 1, '內容', const []);

      expect(result.ok, isFalse);
      expect(result.messages, ['送出失敗']);
    });

    test('挑回來的附件：太大與超過數量的擋掉', () async {
      moodle.posts = Ok([post(1)]);
      moodle.policy = const Ok(
          ForumAttachPolicy(enabled: true, maxFiles: 1, maxBytes: 10));
      await open();
      final dir = await Directory.systemTemp.createTemp('forum_bridge_test');
      addTearDown(() => dir.delete(recursive: true));
      Future<String> file(String name, int bytes) async {
        final f = File('${dir.path}/$name');
        await f.writeAsBytes(List.filled(bytes, 1));
        return f.path;
      }

      final check = await bridge.checkAttachments(9, const [], [
        await file('a.png', 5),
        await file('big.png', 20),
        await file('c.png', 5),
      ]);

      expect(check.accepted.map((p) => p.split('/').last), ['a.png']);
      expect(check.messages, hasLength(2));
    });
  });

  group('編輯與刪除', () {
    test('編輯窗已經關了：說一聲並重抓討論串，不開編輯頁', () async {
      moodle.posts = Ok([post(1, edit: true)]);
      await open();
      moodle.postForEdit = (
        id: 1,
        subject: '期中考範圍',
        rawMessage: '<p>內容</p>',
        rawFormat: 1,
        canEdit: false,
        attachments: <MoodleForumFile>[],
      );

      final start = await bridge.startEdit(9, 1);

      expect(start.draft, isNull);
      expect(start.message, '已超過可以編輯的時間');
      expect(start.thread, isNotNull);
    });

    test('純文字貼文開純文字框；有圖片的開所見即所得，內容由核心逃脫', () async {
      moodle.posts = Ok([post(1, edit: true), post(2, parent: 1, edit: true)]);
      await open();

      moodle.postForEdit = (
        id: 1,
        subject: '期中考範圍',
        rawMessage: '第一行\n第二行',
        rawFormat: 2,
        canEdit: true,
        attachments: <MoodleForumFile>[],
      );
      final plain = (await bridge.startEdit(9, 1)).draft!;
      expect(plain.mode, ForumEditorMode.plain);
      expect(plain.text, '第一行\n第二行');
      expect(plain.isTopicPost, isTrue);

      moodle.postForEdit = (
        id: 2,
        subject: '回覆',
        rawMessage: '<p><img src="@@PLUGINFILE@@/a.png"></p>',
        rawFormat: 1,
        canEdit: true,
        attachments: <MoodleForumFile>[],
      );
      final rich = (await bridge.startEdit(9, 2)).draft!;
      expect(rich.mode, ForumEditorMode.rich);
      expect(rich.text, isNull);
      expect(rich.editorScript, startsWith('window.__tatEditor.setContent('));
    });

    test('改第一篇：標題換成伺服器重讀回來的那一份，清單那一列也要重抓', () async {
      moodle.posts = Ok([post(1, edit: true)]);
      await open();
      moodle.postForEdit = (
        id: 1,
        subject: '期中考範圍',
        rawMessage: '內容',
        rawFormat: 2,
        canEdit: true,
        attachments: <MoodleForumFile>[],
      );
      await bridge.startEdit(9, 1);
      moodle.editResult = const Ok(ForumEditOutcome());
      moodle.posts = Ok([post(1, edit: true, subject: '期末考範圍')]);

      final result =
          await bridge.saveEdit(9, 1, '期末考範圍', '內容', const [], const []);

      expect(result.ok, isTrue);
      expect(result.listChanged, isTrue);
      expect(result.messages, ['已更新']);
      expect(result.thread?.title, '期末考範圍');
    });

    test('刪回覆重讀討論串；刪第一篇整串就沒了', () async {
      moodle.posts =
          Ok([post(1, delete: true), post(2, parent: 1, delete: true)]);
      final before = await open();
      expect(before.posts.first.hasReplies, isTrue,
          reason: '底下有回覆的貼文，刪除要停用並附理由');
      moodle.deleteResult = const Ok(true);
      moodle.posts = Ok([post(1, delete: true)]);

      final reply = await bridge.deletePost(9, 2);
      expect(reply.closeThread, isFalse);
      expect(reply.thread?.posts.map((p) => p.id), [1]);

      final topic = await bridge.deletePost(9, 1);
      expect(topic.closeThread, isTrue);
      expect(topic.messages, ['已刪除']);
    });
  });
}
