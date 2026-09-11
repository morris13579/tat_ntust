import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_draft_area.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_access_information.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forums_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_forum_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 附件、編輯與刪除三條寫入路徑的規格。只換掉真的會送出去的那幾步。
class _FakeRepo extends MoodleRepository {
  int draftId = 884411;

  MoodleApiException? draftError;
  MoodleApiException? prepareError;
  MoodleApiException? replyError;
  MoodleApiException? updateError;
  MoodleApiException? deleteError;

  /// `add_discussion_post` 回應裡伺服器實際收下的附件。
  List<MoodleForumFile> serverAttachments = const [];

  /// 重讀那一趟拿到的附件（編輯路徑）。
  List<MoodleForumFile> refreshedAttachments = const [];
  bool refreshFails = false;

  final uploadedNames = <String>[];
  final uploadedItemIds = <int?>[];
  final prepareCalls = <List<({String filename, String filepath})>>[];
  final updateAttachmentIds = <int?>[];
  final updateMessages = <String>[];
  final updateFormats = <int>[];
  int? replyAttachmentsId;
  int deleteCalls = 0;
  int updateCalls = 0;
  final progress = <ForumTransferProgress>[];

  @override
  Future<int?> writeDraftFile(
    File file, {
    required String filename,
    int? draftItemId,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    uploadedNames.add(filename);
    uploadedItemIds.add(draftItemId);
    final error = draftError;
    if (error != null) throw error;
    onProgress?.call(50, 100);
    return draftId;
  }

  @override
  Future<MoodleForumDraftArea> writeForumDraftArea({
    required int postId,
    required List<({String filename, String filepath})> filesToKeep,
    String area = MoodleWebApiConnector.forumDraftAreaAttachment,
  }) async {
    prepareCalls.add(filesToKeep);
    final error = prepareError;
    if (error != null) throw error;
    return MoodleForumDraftArea(draftitemid: draftId, maxbytes: 262144);
  }

  @override
  Future<MoodleForumPost> writeReply({
    required int postId,
    required String subject,
    required String message,
    int? attachmentsId,
  }) async {
    replyAttachmentsId = attachmentsId;
    final error = replyError;
    if (error != null) throw error;
    return MoodleForumPost(id: 950, attachments: [...serverAttachments]);
  }

  @override
  Future<void> writePostUpdate({
    required int postId,
    required String subject,
    required String message,
    required int messageFormat,
    int? attachmentsId,
    int? inlineAttachmentsId,
  }) async {
    updateCalls++;
    updateAttachmentIds.add(attachmentsId);
    updateMessages.add(message);
    updateFormats.add(messageFormat);
    final error = updateError;
    if (error != null) throw error;
  }

  @override
  Future<void> writePostDelete(int postId) async {
    deleteCalls++;
    final error = deleteError;
    if (error != null) throw error;
  }

  @override
  Future<ForumPostEdit?> fetchPostForEdit(int postId) async {
    if (refreshFails) return null;
    return (
      id: postId,
      subject: 's',
      rawMessage: 'm',
      rawFormat: 1,
      canEdit: true,
      attachments: [...refreshedAttachments],
    );
  }

  @override
  Future<List<MoodleForum>?> fetchForums(String courseId) async => [
        MoodleForum(id: 5499, maxattachments: 3, maxbytes: 512000),
      ];

  @override
  Future<MoodleForumAccess?> fetchForumAccess(int forumId) async =>
      fixtureForumAccess();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late Directory temp;

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() async {
    resetAppStatics();
    repo = _FakeRepo();
    MoodleRepository.instance = repo;
    AuthSession.instance = FakeAuthSession();
    TaskUiDelegate.instance = RecordingUi();
    ConnectivityProbe.instance = FakeConnectivityProbe();
    MoodleWebApiConnector.wsToken = 'tok';
    // upload.php 開著，而且站台上限比討論區寬鬆。
    MoodleWebApiConnector.siteInfo =
        MoodleProfileEntity(uploadfiles: 1, usermaxuploadfilesize: 5000000);
    temp = await Directory.systemTemp.createTemp('tat_forum_attach');
  });

  tearDown(() async {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<File> file(String name, {int bytes = 16}) async {
    final f = File('${temp.path}/$name');
    await f.writeAsBytes(List<int>.filled(bytes, 65));
    return f;
  }

  const policy =
      ForumAttachPolicy(enabled: true, maxFiles: 3, maxBytes: 512000);

  MoodleForumFile online(String name) =>
      MoodleForumFile(filename: name, url: 'https://x/$name');

  group('postReply 帶附件', () {
    test('先建 draft 區再送出，attachmentsid 一路帶到 add_discussion_post', () async {
      repo.serverAttachments = [online('a.pdf'), online('b.pdf')];

      final result = await repo.postReply(
        postId: 900,
        subject: 's',
        text: 'm',
        attachments: [await file('a.pdf'), await file('b.pdf')],
        policy: policy,
      );

      expect(result, isA<Ok<ForumReplyOutcome>>());
      expect(result.dataOrNull?.warning, isNull);
      expect(repo.uploadedNames, ['a.pdf', 'b.pdf']);
      // 第一個開新的 draft 區，其餘送回同一個 itemid。
      expect(repo.uploadedItemIds, [null, 884411]);
      expect(repo.replyAttachmentsId, 884411);
    });

    test('伺服器靜靜丟掉一個附件 → **帶 warning 的成功**，不是失敗', () async {
      // 這就是 add_discussion_post_attachment_dropped 的形狀：送兩個、回一個，
      // 而且 warnings[] 是空的。
      repo.serverAttachments = [online('a.pdf')];

      final result = await repo.postReply(
        postId: 900,
        subject: 's',
        text: 'm',
        attachments: [await file('a.pdf'), await file('b.pdf')],
        policy: policy,
      );

      expect(result, isA<Ok<ForumReplyOutcome>>(), reason: '貼文真的發出去了，不可以報成失敗');
      expect(result.dataOrNull!.warning, contains('b.pdf'),
          reason: '也不可以裝作全部都上去了');
    });

    test('政策說不給附件時整趟不送，一個位元組都沒出去', () async {
      final result = await repo.postReply(
        postId: 900,
        subject: 's',
        text: 'm',
        attachments: [await file('a.pdf')],
      );

      expect((result as Failed<ForumReplyOutcome>).reason.message,
          R.current.forumAttachmentDisabled);
      expect(repo.uploadedNames, isEmpty);
      expect(repo.replyAttachmentsId, isNull);
    });

    test('重名先在本地擋掉：upload.php 會回 filenameexist，而那時 draft 區已經半套', () async {
      final result = await repo.postReply(
        postId: 900,
        subject: 's',
        text: 'm',
        attachments: [await file('a.pdf'), await file('A.PDF')],
        policy: policy,
      );

      expect((result as Failed<ForumReplyOutcome>).reason.message,
          R.current.forumAttachmentDuplicateName);
      expect(repo.uploadedNames, isEmpty);
    });

    test('超過檔案數在本地擋掉：伺服器只會靜靜丟掉多的', () async {
      final result = await repo.postReply(
        postId: 900,
        subject: 's',
        text: 'm',
        attachments: [
          await file('a.pdf'),
          await file('b.pdf'),
          await file('c.pdf'),
          await file('d.pdf'),
        ],
        policy: policy,
      );

      expect(result, isA<Failed<ForumReplyOutcome>>());
      expect(repo.uploadedNames, isEmpty);
    });

    test('超過單檔上限在本地擋掉', () async {
      final result = await repo.postReply(
        postId: 900,
        subject: 's',
        text: 'm',
        attachments: [await file('big.pdf', bytes: 4096)],
        policy:
            const ForumAttachPolicy(enabled: true, maxFiles: 3, maxBytes: 1024),
      );

      expect((result as Failed<ForumReplyOutcome>).reason.message,
          contains('big.pdf'));
      expect(repo.uploadedNames, isEmpty);
    });

    test('沒有附件時完全不送 attachmentsid——不送等於沒有附件', () async {
      final result = await repo.postReply(postId: 900, subject: 's', text: 'm');

      expect(result, isA<Ok<ForumReplyOutcome>>());
      expect(repo.replyAttachmentsId, isNull);
    });
  });

  group('editPost', () {
    test('原本沒有附件、也沒加 → **不送** attachmentsid（旗標本來就是空的）', () async {
      final result = await repo.editPost(
        rawFormat: MoodleForumUtils.formatPlain,
        postId: 950,
        subject: 's',
        text: 'm',
        keepAttachments: const [],
        newAttachments: const [],
        hadAttachments: false,
      );

      expect(result, isA<Ok<ForumEditOutcome>>());
      expect(repo.prepareCalls, isEmpty);
      expect(repo.updateAttachmentIds, [null]);
    });

    test('原本有附件 → **一定送** attachmentsid，否則 attachment 旗標會被清成空字串', () async {
      repo.refreshedAttachments = [online('a.pdf')];

      await repo.editPost(
        rawFormat: MoodleForumUtils.formatPlain,
        postId: 950,
        subject: 's',
        text: 'm',
        keepAttachments: [online('a.pdf')],
        newAttachments: const [],
        hadAttachments: true,
        policy: policy,
      );

      expect(repo.prepareCalls, hasLength(1));
      expect(repo.prepareCalls.single.map((f) => f.filename), ['a.pdf']);
      expect(repo.updateAttachmentIds, [884411]);
    });

    test('把既有附件全部移除時送哨兵名單——空陣列是「全部保留」，不是「全部刪掉」', () async {
      await repo.editPost(
        rawFormat: MoodleForumUtils.formatPlain,
        postId: 950,
        subject: 's',
        text: 'm',
        keepAttachments: const [],
        newAttachments: const [],
        hadAttachments: true,
        policy: policy,
      );

      expect(repo.prepareCalls.single, hasLength(1));
      expect(repo.prepareCalls.single.single.filename, isNotEmpty);
      expect(repo.updateAttachmentIds, [884411]);
    });

    test('新加的檔案傳進同一個 draft 區', () async {
      repo.refreshedAttachments = [online('a.pdf'), online('new.pdf')];

      await repo.editPost(
        rawFormat: MoodleForumUtils.formatPlain,
        postId: 950,
        subject: 's',
        text: 'm',
        keepAttachments: [online('a.pdf')],
        newAttachments: [await file('new.pdf')],
        hadAttachments: true,
        policy: policy,
      );

      expect(repo.uploadedNames, ['new.pdf']);
      expect(repo.uploadedItemIds, [884411], reason: '種好的那一區，不是新開一個');
    });

    test('站台沒開 prepare_draft_area_for_post 而貼文有附件 → 拒絕，一個請求都不送', () async {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(
        uploadfiles: 1,
        functions: [
          MoodleProfileFunctions(
              name: MoodleWebApiConnector.updateDiscussionPostFunction,
              version: '4.5'),
        ],
      );

      final result = await repo.editPost(
        rawFormat: MoodleForumUtils.formatPlain,
        postId: 950,
        subject: 's',
        text: 'm',
        keepAttachments: [online('a.pdf')],
        newAttachments: const [],
        hadAttachments: true,
        policy: policy,
      );

      // 唯一剩下的那條路是「不送 attachmentsid」，而那會把
      // forum_posts.attachment 清成空字串——主題清單的迴紋針憑空消失。
      // 那不是降級，是弄壞資料，所以整個動作拒絕。
      expect(result, isA<Failed<ForumEditOutcome>>());
      expect((result as Failed<ForumEditOutcome>).reason.message,
          R.current.forumEditAttachmentsWebOnly);
      expect(repo.prepareCalls, isEmpty);
      expect(repo.updateCalls, 0, reason: '沒有半個寫入');
    });

    test('站台沒開 prepare_draft_area_for_post 但貼文本來就沒有附件 → 照樣更新', () async {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(
        uploadfiles: 1,
        functions: [
          MoodleProfileFunctions(
              name: MoodleWebApiConnector.updateDiscussionPostFunction,
              version: '4.5'),
        ],
      );

      final result = await repo.editPost(
        rawFormat: MoodleForumUtils.formatPlain,
        postId: 950,
        subject: 's',
        text: 'm',
        keepAttachments: const [],
        newAttachments: const [],
        hadAttachments: false,
      );

      expect(result, isA<Ok<ForumEditOutcome>>());
      expect(repo.prepareCalls, isEmpty);
      expect(repo.updateAttachmentIds, [null], reason: '旗標本來就是空的，不送不會弄壞任何東西');
    });

    test('空內文 → 直接失敗，一個請求都不送（伺服器會靜靜不改然後回 status: true）', () async {
      final result = await repo.editPost(
        rawFormat: MoodleForumUtils.formatPlain,
        postId: 950,
        subject: 's',
        text: '   ',
        keepAttachments: const [],
        newAttachments: const [],
        hadAttachments: false,
      );

      expect(result, isA<Failed<ForumEditOutcome>>());
      expect(repo.updateCalls, 0);
    });

    test('空標題 → 直接失敗', () async {
      final result = await repo.editPost(
        rawFormat: MoodleForumUtils.formatPlain,
        postId: 950,
        subject: '  ',
        text: 'm',
        keepAttachments: const [],
        newAttachments: const [],
        hadAttachments: false,
      );

      expect(result, isA<Failed<ForumEditOutcome>>());
      expect(repo.updateCalls, 0);
    });

    test('cannotupdatepost → 一句每種原因都成立的話，而且不提網頁', () async {
      repo.updateError =
          MoodleApiException(wsFunction: 'x', errorcode: 'cannotupdatepost');

      final result = await repo.editPost(
        rawFormat: MoodleForumUtils.formatPlain,
        postId: 950,
        subject: 's',
        text: 'm',
        keepAttachments: const [],
        newAttachments: const [],
        hadAttachments: false,
      );

      final message = (result as Failed<ForumEditOutcome>).reason.message;
      expect(message, R.current.forumErrorNoEditPermission);
      expect(message, isNot(contains(R.current.forumOpenInWeb)));
    });

    test('重讀時附件少了 → 帶 warning 的成功', () async {
      repo.refreshedAttachments = const [];

      final result = await repo.editPost(
        rawFormat: MoodleForumUtils.formatPlain,
        postId: 950,
        subject: 's',
        text: 'm',
        keepAttachments: [online('a.pdf')],
        newAttachments: const [],
        hadAttachments: true,
        policy: policy,
      );

      expect(result, isA<Ok<ForumEditOutcome>>());
      expect(result.dataOrNull!.warning, contains('a.pdf'));
    });
  });

  group('deletePost', () {
    test('刪回覆：不碰快取，也不重讀（重讀由呼叫端決定）', () async {
      await MoodleRepository.instance
          .saveDiscussionPosts(7701, [MoodleForumPost(id: 900)]);

      final result = await repo.deletePost(
          postId: 950, isTopicPost: false, discussionId: 7701);

      expect(result, isA<Ok<bool>>());
      expect(repo.deleteCalls, 1);
      expect(
          await CacheStore.instance
              .read(MoodleRepository.discussionPostsKey(7701)),
          isNotNull);
    });

    test('刪主文：那一串的快取被清掉，而且**沒有**再打 get_discussion_posts', () async {
      await MoodleRepository.instance
          .saveDiscussionPosts(7701, [MoodleForumPost(id: 900)]);

      final result = await repo.deletePost(
          postId: 900, isTopicPost: true, discussionId: 7701);

      expect(result, isA<Ok<bool>>());
      expect(
          await CacheStore.instance
              .read(MoodleRepository.discussionPostsKey(7701)),
          isNull,
          reason: '討論串已經不存在，留著就是一份指向空氣的舊資料');
    });

    test('couldnotdeletereplies → 「有人回覆過就不能刪」，而且不提網頁', () async {
      repo.deleteError = MoodleApiException(
          wsFunction: 'x', errorcode: 'couldnotdeletereplies');

      final result = await repo.deletePost(
          postId: 950, isTopicPost: false, discussionId: 7701);

      final message = (result as Failed<bool>).reason.message;
      expect(message, R.current.forumCannotDeleteHasReplies);
      expect(message, isNot(contains(R.current.forumOpenInWeb)));
    });

    test('couldnotdeleteratings → 被評過分就不能刪', () async {
      repo.deleteError = MoodleApiException(
          wsFunction: 'x', errorcode: 'couldnotdeleteratings');

      final result = await repo.deletePost(
          postId: 950, isTopicPost: false, discussionId: 7701);

      expect((result as Failed<bool>).reason.message,
          R.current.forumCannotDeleteRated);
    });
  });

  group('getForumAttachPolicy', () {
    test('全部條件都過 → enabled，上限取正值中的最小', () async {
      final result =
          await repo.getForumAttachPolicy(courseId: '1234', forumId: 5499);

      expect(result.dataOrNull!.enabled, isTrue);
      expect(result.dataOrNull!.maxFiles, 3);
      expect(result.dataOrNull!.maxBytes, 512000);
    });

    test('站台關掉 upload.php → off，而且不多問兩支 function', () async {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(uploadfiles: 0);

      final result =
          await repo.getForumAttachPolicy(courseId: '1234', forumId: 5499);

      expect(result.dataOrNull!.enabled, isFalse);
    });

    test('forumId 不明（舊快取）→ off', () async {
      final result =
          await repo.getForumAttachPolicy(courseId: '1234', forumId: 0);

      expect(result.dataOrNull!.enabled, isFalse);
    });

    test('cancreateattachment 是 false → off（附件會被靜靜丟掉，先擋住）', () async {
      final quiet = _QuietAccessRepo();
      MoodleRepository.instance = quiet;

      final result =
          await quiet.getForumAttachPolicy(courseId: '1234', forumId: 5499);

      expect(result.dataOrNull!.enabled, isFalse);
    });
  });
}

class _QuietAccessRepo extends _FakeRepo {
  @override
  Future<MoodleForumAccess?> fetchForumAccess(int forumId) async =>
      fixtureForumAccess('get_forum_access_information_no_attachment');
}
