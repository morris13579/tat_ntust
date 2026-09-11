import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_draft_area.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 所見即所得那條寫入路徑的規格。
///
/// 這一支盯著的是**兩種一致模式不可以混**：要嘛完全不碰 draft 區、內容原樣
/// 存（`IGNORE_FILE_MERGE`），要嘛開 draft 區＋換網址＋送 itemid 三件事一起做。
/// 混起來的每一種組合都會讓貼文裡的圖片永久壞掉或被刪光。
class _FakeRepo extends MoodleRepository {
  int draftId = 990011;

  /// draft 區回的 `messagetext`；預設帶著對得上 [draftId] 的網址前綴。
  String? messageText;

  MoodleApiException? prepareError;

  final prepareAreas = <String>[];
  final prepareFilesToKeep = <List<({String filename, String filepath})>>[];
  final updateMessages = <String>[];
  final updateFormats = <int>[];
  final updateInlineIds = <int?>[];
  int updateCalls = 0;

  @override
  Future<MoodleForumDraftArea> writeForumDraftArea({
    required int postId,
    required List<({String filename, String filepath})> filesToKeep,
    String area = MoodleWebApiConnector.forumDraftAreaAttachment,
  }) async {
    prepareAreas.add(area);
    prepareFilesToKeep.add(filesToKeep);
    final error = prepareError;
    if (error != null) throw error;
    return MoodleForumDraftArea(
      draftitemid: draftId,
      messagetext: messageText ??
          '<p><img src="https://moodle2.ntust.edu.tw/draftfile.php/123/'
              'user/draft/$draftId/scope.png"></p>',
    );
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
    updateMessages.add(message);
    updateFormats.add(messageFormat);
    updateInlineIds.add(inlineAttachmentsId);
  }

  @override
  Future<ForumPostEdit?> fetchPostForEdit(int postId) async => (
        id: postId,
        subject: 's',
        rawMessage: 'm',
        rawFormat: MoodleForumUtils.formatHtml,
        canEdit: true,
        attachments: const <MoodleForumFile>[],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const host = 'https://moodle2.ntust.edu.tw';
  const draftPrefix = '$host/draftfile.php/123/user/draft/990011/';

  late _FakeRepo repo;

  setUpAll(() async {
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MoodleRepository.instance = repo;
    AuthSession.instance = FakeAuthSession();
    TaskUiDelegate.instance = RecordingUi();
    ConnectivityProbe.instance = FakeConnectivityProbe();
    // 真的 token 是 32 個十六進位字元。用 'tok' 這種短字串會讓「內文提到
    // token=」被當成 token 本身出現，測出來的綠是假的。
    MoodleWebApiConnector.wsToken = '0f1e2d3c4b5a69788796a5b4c3d2e1f0';
    MoodleWebApiConnector.siteInfo = MoodleProfileEntity();
    // 探測「已完成、不支援」，`fileUrlWithToken` 於是固定回 `?token=`；
    // 不釘住的話它會在測試裡開一趟真的探測。
    MoodleWebApiConnector.tokenPluginFileWorks = false;
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    resetAppStatics();
  });

  /// `messageinlinefiles[].url` 真正的樣子：`stored_file_exporter` 用
  /// `make_pluginfile_url($…, $forcedownload = true)` 組，所以是
  /// **`pluginfile.php` 加上 `?forcedownload=1`**，不是 `webservice/` 那一支。
  MoodleForumFile inlineFile(String name) => MoodleForumFile(
        filename: name,
        filepath: '/',
        url: '$host/pluginfile.php/8801/mod_forum/post/951/$name'
            '?forcedownload=1',
      );

  /// 編輯器裡看到的樣子：網址已經帶著憑證。
  String editorHtml(String name) => '<p>期中考範圍 <b>重要</b></p><p><img src="'
      '${MoodleWebApiConnector.fileUrlWithToken(inlineFile(name).url)}"></p>';

  Future<Result<ForumEditOutcome>> edit({
    required String html,
    required List<MoodleForumFile> inlineFiles,
    int rawFormat = MoodleForumUtils.formatHtml,
  }) =>
      repo.editPost(
        postId: 951,
        subject: '標題',
        text: html,
        rawFormat: rawFormat,
        keepAttachments: const [],
        newAttachments: const [],
        hadAttachments: false,
        inlineHtml: html,
        inlineFiles: inlineFiles,
      );

  group('有內嵌圖片', () {
    test('用 area=post 開 draft 區、filestokeep 是空的，itemid 送進 update', () async {
      final result = await edit(
          html: editorHtml('scope.png'),
          inlineFiles: [inlineFile('scope.png')]);

      expect(result, isA<Ok<ForumEditOutcome>>());
      expect(repo.prepareAreas, [MoodleWebApiConnector.forumDraftAreaPost]);
      // 非空的名單會刪掉不在名單上的檔案，而那正是要保護的圖片。
      expect(repo.prepareFilesToKeep.single, isEmpty);
      expect(repo.updateInlineIds.single, 990011);
    });

    test('圖片網址換成 draft 區的，憑證與 pluginfile 一個都不剩', () async {
      await edit(
          html: editorHtml('scope.png'),
          inlineFiles: [inlineFile('scope.png')]);

      final message = repo.updateMessages.single;
      expect(message, contains('src="${draftPrefix}scope.png"'));
      expect(message.contains('pluginfile.php'), isFalse);
      expect(message.contains('token='), isFalse);
      // 排版原封不動。
      expect(message, contains('<b>重要</b>'));
    });

    test('messagetext 裡挑不出前綴 → 整趟放棄，一個字都不寫進去', () async {
      repo.messageText = '<p>沒有任何 draft 網址</p>';

      final result = await edit(
          html: editorHtml('scope.png'),
          inlineFiles: [inlineFile('scope.png')]);

      expect(result, isA<Failed<ForumEditOutcome>>());
      expect(repo.updateCalls, 0);
    });

    test('itemid 對不上（別的 draft 區）也一樣放棄', () async {
      repo.messageText = '<p><img src="$host/draftfile.php/123/user/draft/'
          '777/scope.png"></p>';

      final result = await edit(
          html: editorHtml('scope.png'),
          inlineFiles: [inlineFile('scope.png')]);

      expect(result, isA<Failed<ForumEditOutcome>>());
      expect(repo.updateCalls, 0);
    });

    test('有一張圖沒換回去 → fail closed，token 不會被寫進貼文', () async {
      // 對照表裡只有 scope.png，畫面上卻還有第二張帶憑證的圖。
      final html = '${editorHtml('scope.png')}${editorHtml('extra.png')}';

      final result =
          await edit(html: html, inlineFiles: [inlineFile('scope.png')]);

      switch (result) {
        case Failed(:final reason):
          expect(reason.message, R.current.forumEditorUnsafeContent);
        default:
          fail('應該要失敗：$result');
      }
      expect(repo.updateCalls, 0);
    });
  });

  group('沒有內嵌圖片', () {
    test('完全不打 prepare_draft_area_for_post，inlineattachmentsid 也不送', () async {
      const html = '<table><tr><td>1</td></tr></table>';

      final result = await edit(html: html, inlineFiles: const []);

      expect(result, isA<Ok<ForumEditOutcome>>());
      expect(repo.prepareAreas, isEmpty);
      expect(repo.updateInlineIds.single, isNull);
      // IGNORE_FILE_MERGE：內容原樣存，既有檔案動都不動。
      expect(repo.updateMessages.single, html);
    });

    test('檔案區裡有孤兒、但內文引用不到時，也一樣不碰 draft 區', () async {
      // 使用者在網頁版刪掉 <img> 之後 Moodle 不會把檔案從 filearea 拿掉，
      // messageinlinefiles 於是留著 orphan.png。改用「內文有沒有引用」判斷之
      // 前，這裡會去開一個 messagetext 裡沒有 draftfile 網址的 draft 區，
      // 前綴挑不出來 → 這則貼文從此永遠存不回去。
      const html = '<p><strong>重要</strong>：期中考改期</p>';
      repo.messageText = html;

      final result =
          await edit(html: html, inlineFiles: [inlineFile('orphan.png')]);

      expect(result, isA<Ok<ForumEditOutcome>>());
      expect(repo.prepareAreas, isEmpty);
      expect(repo.updateInlineIds.single, isNull);
      expect(repo.updateMessages.single, html);
    });

    test('內文有別的 filearea 的絕對檔案網址時照樣存得進去', () async {
      // 從課程頁複製過來的網址永遠不會出現在內嵌清單裡。擋掉它等於把
      // 「請去網頁編輯」那條死路原封不動搬到儲存鈕上。
      const html = '<p>參考：<a href="$host/pluginfile.php/1200102/'
          'mod_resource/content/2/intro.pptx">投影片</a>，token= 那一段</p>';

      final result = await edit(html: html, inlineFiles: const []);

      expect(result, isA<Ok<ForumEditOutcome>>());
      expect(repo.updateMessages.single, html);
    });
  });

  group('格式', () {
    test('messageFormat 一定是帶進來的那一個，不是寫死的常數', () async {
      for (final format in [MoodleForumUtils.formatHtml, 4]) {
        repo.updateFormats.clear();
        await edit(html: '<p>x</p>', inlineFiles: const [], rawFormat: format);
        expect(repo.updateFormats.single, format);
      }
    });
  });

  group('空內容', () {
    test('編輯器吐回空字串時擋下來——伺服器對空 message 是「不改」卻回 status: true', () async {
      final result = await edit(html: '   ', inlineFiles: const []);

      expect(result, isA<Failed<ForumEditOutcome>>());
      expect(repo.updateCalls, 0);
    });
  });
}
