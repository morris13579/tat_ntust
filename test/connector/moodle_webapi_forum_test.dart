import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_forum_fixtures.dart';

/// 公告三支 function 回應的本機判讀規格。判讀抽成公開純函式（與 `assignmentsOf`
/// 同慣例），不碰網路。
void main() {
  void resetConnectorStatics() {
    MoodleWebApiConnector.siteInfo = null;
    MoodleWebApiConnector.userId = null;
    MoodleWebApiConnector.onApiError = null;
    MoodleWebApiConnector.wsToken = null;
  }

  setUp(resetConnectorStatics);
  tearDown(() {
    resetConnectorStatics();
    MoodleWebApiConnector.resetAutologinState();
  });

  group('forumsOf', () {
    test('回的是陣列本身，不是 {forums: []}；不建模的欄位被忽略而不是拋', () {
      final forums = MoodleWebApiConnector.forumsOf(
          loadMoodleForumListFixture('get_forums_by_courses'));

      expect(forums, isNotNull);
      expect(forums!.map((f) => f.id), [5499, 5500, 5501]);
      expect(forums.last.type, 'news');
      expect(forums.last.cmid, 91001);
      expect(forums.last.numdiscussions, 2);
    });

    test('Map（錯誤回應的形狀）與其他型別一律回 null', () {
      expect(
          MoodleWebApiConnector.forumsOf({
            'exception': 'webservice_access_exception',
            'errorcode': 'accessexception',
            'message': '存取被拒',
          }),
          isNull);
      expect(MoodleWebApiConnector.forumsOf(null), isNull);
      expect(MoodleWebApiConnector.forumsOf('[]'), isNull);
    });
  });

  group('pickAnnouncementForum', () {
    test('type == news 勝過名稱比對——即使名稱像公告的那一筆排在前面', () {
      final forums = fixtureForums();

      // 這就是這次改動要修的迴歸：課程公佈欄在 index 1，公告區在 index 2。
      expect(MoodleWebApiConnector.pickAnnouncementForum(forums)?.id, 5501);
    });

    test('沒有 news 也沒有像公告的名稱 → null（這門課沒有公告區）', () {
      final forums = fixtureForums('get_forums_by_courses_no_news');

      expect(MoodleWebApiConnector.pickAnnouncementForum(forums), isNull);
    });

    test('只有名稱像公告的一般討論區時退回名稱比對', () {
      final forums = fixtureForums()
        ..removeWhere((f) => f.type == MoodleWebApiConnector.newsForumType);

      expect(MoodleWebApiConnector.pickAnnouncementForum(forums)?.id, 5500);
    });

    test('空清單 → null', () {
      expect(MoodleWebApiConnector.pickAnnouncementForum(const []), isNull);
    });
  });

  group('looksLikeAnnouncementName', () {
    test('四種寫法都認得，一般討論區不算', () {
      for (final name in ['公告', '課程公佈欄', 'Announcements', 'News forum']) {
        expect(MoodleWebApiConnector.looksLikeAnnouncementName(name), isTrue,
            reason: name);
      }
      expect(MoodleWebApiConnector.looksLikeAnnouncementName('討論區'), isFalse);
      expect(MoodleWebApiConnector.looksLikeAnnouncementName(''), isFalse);
    });
  });

  group('legacyAnnouncementForumId', () {
    test('「一般」段落裡名稱像公告的模組 → 它的 instance id', () {
      expect(
          MoodleWebApiConnector.legacyAnnouncementForumId(
              fixtureCourseContents()),
          5500);
    });

    test('沒有「一般」段落 → null', () {
      final contents = fixtureCourseContents()
        ..removeWhere((s) => s.name.contains('一般'));

      expect(MoodleWebApiConnector.legacyAnnouncementForumId(contents), isNull);
    });

    test('有「一般」段落但沒有像公告的模組 → null', () {
      final contents = fixtureCourseContents();
      contents.first.modules.removeWhere(
          (m) => m.name.contains('課程公佈欄') || m.name.contains('公告'));

      expect(MoodleWebApiConnector.legacyAnnouncementForumId(contents), isNull);
    });
  });

  group('announcementsOf', () {
    test('name 與 subject 的 HTML 實體會被還原，forumFound 預設是 true', () {
      final parsed = fixtureDiscussions();

      expect(parsed.forumFound, isTrue);
      expect(parsed.discussions, hasLength(2));
      expect(parsed.discussions[0].name, '期中考 & 補考公告');
      // subject 是抓不到回覆時退路貼文的標題，同樣是純文字 sink。
      expect(parsed.discussions[0].subject, '期中考 & 補考公告');
      expect(parsed.discussions[0].subject, isNot(contains('&amp;')));
      expect(parsed.discussions[0].pinned, isTrue);
      expect(parsed.discussions[0].numreplies, 3);
      expect(parsed.discussions[1].pinned, isFalse);
      expect(parsed.discussions[1].numreplies, 0);
    });

    test('id 是第一篇貼文的 id，discussion 才是討論串 id', () {
      final d = fixtureDiscussions().discussions.first;

      expect(d.id, 8801);
      expect(d.discussion, 7701);
      expect(d.id, isNot(d.discussion));
    });

    test('形狀不對回 null', () {
      expect(MoodleWebApiConnector.announcementsOf(const []), isNull);
      expect(MoodleWebApiConnector.announcementsOf(null), isNull);
    });
  });

  group('getCourseAnnouncement 的錯誤', () {
    tearDown(MoodleWebApiConnector.resetAutologinState);

    test('公告區兩條路都失敗時，往上帶的是原本的 MoodleApiException', () async {
      final errors = <MoodleApiException>[];
      MoodleWebApiConnector.onApiError = errors.add;
      MoodleWebApiConnector.wsPost = (_) async => const {
            'exception': 'moodle_exception',
            'errorcode': 'invalidtoken',
            'message': 'Invalid token - token not found',
          };

      expect(await MoodleWebApiConnector.getCourseAnnouncement('7788'), isNull);

      // 換成一般 Exception 的話 _reportFailure 會走 Log.eWithStack，
      // token 過期就被當成當機送進 Crashlytics，而且 onApiError 也收不到。
      expect(
        errors.map((e) => e.wsFunction),
        [
          'core_course_get_contents',
          MoodleWebApiConnector.forumsByCoursesFunction
        ],
      );
      expect(errors.last.errorcode, 'invalidtoken');
    });
  });

  group('discussionPostsOf', () {
    test('四篇貼文維持伺服器順序，subject 的實體被還原', () {
      final posts = fixturePosts();

      expect(posts.map((p) => p.id), [900, 901, 902, 903]);
      expect(posts.first.subject, '期中考 & 補考公告');
      expect(posts.first.subject, isNot(contains('&amp;')));
    });

    test('@@PLUGINFILE@@ 換成 messageinlinefiles 的網址前綴', () {
      final posts = fixturePosts();

      expect(posts.first.message, isNot(contains('@@PLUGINFILE@@')));
      expect(
        posts.first.message,
        // `@@PLUGINFILE@@` 換出來的前綴是 url 砍掉 query 之後的那一段：
        // stored_file_exporter 的 url 一定帶著 `?forcedownload=1`。
        contains('https://moodle2.ntust.edu.tw/pluginfile.php/123'
            '/mod_forum/post/900/inline%20image.png"'),
      );
    });

    test('附件的網址欄位是 url（stored_file_exporter），沒有 mimetype', () {
      final f = fixturePosts().first.attachments.single;

      expect(f.filename, 'slides.pdf');
      expect(
          f.url,
          'https://moodle2.ntust.edu.tw/pluginfile.php/123'
          '/mod_forum/attachment/900/slides.pdf?forcedownload=1');
      expect(f.filesize, 88888);
      expect(f.isimage, isFalse);
    });

    test('已刪除的貼文照樣回來，timecreated 是 null', () {
      final deleted = fixturePosts().last;

      expect(deleted.isdeleted, isTrue);
      expect(deleted.timecreated, isNull);
      expect(deleted.attachments, isEmpty);
    });

    test('空 posts 與形狀不對都回 null', () {
      expect(MoodleWebApiConnector.discussionPostsOf({'posts': []}), isNull);
      expect(MoodleWebApiConnector.discussionPostsOf(const []), isNull);
      expect(MoodleWebApiConnector.discussionPostsOf(null), isNull);
    });
  });

  group('discussionPostsOf 的 capabilities 與 messageformat', () {
    test('capabilities.reply 逐篇讀進來：900/901/902 可回，已刪除的 903 不行', () {
      final posts = fixturePosts();

      expect(
          posts.map((p) => p.capabilities?.reply), [true, true, true, false]);
    });

    test('replysubject 的實體被還原（它會原樣送回伺服器當 subject）', () {
      final posts = fixturePosts();

      expect(posts.first.replysubject, 'Re: 期中考 & 補考公告');
      expect(posts.first.replysubject, isNot(contains('&amp;')));
    });

    test('沒有 capabilities 區塊的貼文 → null，不是「全部 false」', () {
      final raw = loadMoodleForumFixture('get_discussion_posts');
      (raw['posts'] as List)
          .map((e) => e as Map<String, dynamic>)
          .forEach((e) => e.remove('capabilities'));

      final posts = MoodleWebApiConnector.discussionPostsOf(raw)!;

      expect(posts.map((p) => p.capabilities), everyElement(isNull));
    });

    test('FORMAT_PLAIN 的貼文只被轉一次——轉完蓋成 HTML，快取讀回來不會再轉', () {
      final raw = loadMoodleForumFixture('get_discussion_posts');
      final first = (raw['posts'] as List).first as Map<String, dynamic>;
      first['message'] = 'a < b\n第二行';
      first['messageformat'] = 2;

      final once = MoodleWebApiConnector.discussionPostsOf(raw)!.first;

      expect(once.message, 'a &lt; b<br>第二行');
      expect(once.messageformat, 1, reason: '轉過了，存進快取的就是 HTML');

      // 快取的往返：把轉好的那一份再餵回去（reader 走的就是這條路），
      // 內容必須一個字都不變。
      final twice = MoodleWebApiConnector.discussionPostsOf({
        'posts': [once.toJson()]
      })!
          .first;
      expect(twice.message, once.message);
    });
  });

  group('addedPostOf', () {
    test('subject 與 replysubject 還原實體，@@PLUGINFILE@@ 換掉', () {
      final post = MoodleWebApiConnector.addedPostOf(
          loadMoodleForumFixture('add_discussion_post'))!;

      expect(post.id, 950);
      expect(post.subject, 'Re: 期中考 & 補考公告');
      expect(post.replysubject, 'Re: 期中考 & 補考公告');
      expect(post.message, isNot(contains('@@PLUGINFILE@@')));
      expect(
        post.message,
        contains('https://moodle2.ntust.edu.tw/pluginfile.php/123'
            '/mod_forum/post/950/inline%20image.png"'),
      );
      expect(post.parentid, 900);
      expect(post.capabilities?.reply, isTrue);
    });

    test('站台的預設編輯器是 textarea 時貼文留在 FORMAT_PLAIN，由客戶端轉', () {
      final post = MoodleWebApiConnector.addedPostOf(
          loadMoodleForumFixture('add_discussion_post_plain'))!;

      expect(post.message, '老師好，<br>請問 a &lt; b 的那一題<br>也在範圍內嗎？');
      expect(post.messageformat, 1);
    });

    test('沒有 post 這個 key、或形狀不對 → null', () {
      expect(MoodleWebApiConnector.addedPostOf(const {'postid': 950}), isNull);
      expect(MoodleWebApiConnector.addedPostOf(const {'post': 'x'}), isNull);
      expect(MoodleWebApiConnector.addedPostOf(const []), isNull);
      expect(MoodleWebApiConnector.addedPostOf(null), isNull);
    });
  });

  group('addDiscussionPost', () {
    test('送出去的參數：messageformat=2 加 topreferredformat，沒有其他 option', () async {
      Map<String, dynamic>? sent;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent = Map<String, dynamic>.from(parameter.data as Map);
        return loadMoodleForumFixture('add_discussion_post');
      };

      final post = await MoodleWebApiConnector.addDiscussionPost(
          postId: 900, subject: 'Re: 期中考', message: 'a < b\nc');

      expect(post.id, 950);
      expect(
          sent!['wsfunction'], MoodleWebApiConnector.addDiscussionPostFunction);
      expect(sent!['postid'], '900');
      expect(sent!['subject'], 'Re: 期中考');
      // 純文字原樣送出：escape 是伺服器在 topreferredformat 那一步做的。
      expect(sent!['message'], 'a < b\nc');
      expect(sent!['messageformat'], '2');
      expect(sent!['options[0][name]'], 'topreferredformat');
      expect(sent!['options[0][value]'], '1');
      // 訂閱行為要跟網頁版一樣，附件與私訊回覆不在範圍內。
      expect(sent!.keys.join(','), isNot(contains('discussionsubscribe')));
      expect(sent!.keys.join(','), isNot(contains('private')));
      expect(sent!.keys.join(','), isNot(contains('attachmentsid')));
    });

    test('errorcode 一路往上拋，不會被吞成 null', () async {
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async =>
          loadMoodleForumFixture('add_discussion_post_nopostforum');

      expect(
        () => MoodleWebApiConnector.addDiscussionPost(
            postId: 900, subject: 's', message: 'm'),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'nopostforum')),
      );
    });

    test('warnings[] 非空也算失敗（寫入路徑的慣例）', () async {
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost =
          (_) async => loadMoodleForumFixture('add_discussion_post_warning');

      expect(
        () => MoodleWebApiConnector.addDiscussionPost(
            postId: 900, subject: 's', message: 'm'),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'nopostforum')),
      );
    });

    test('回應裡沒有 post 一律當成失敗，不可以報成送出成功', () async {
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost =
          (_) async => const {'postid': 950, 'warnings': []};

      expect(
        () => MoodleWebApiConnector.addDiscussionPost(
            postId: 900, subject: 's', message: 'm'),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'couldnotadd')),
      );
    });

    test('invalidtoken 會送出 onApiError，但例外照樣往上拋', () async {
      final errors = <MoodleApiException>[];
      MoodleWebApiConnector.onApiError = errors.add;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async => const {
            'exception': 'moodle_exception',
            'errorcode': 'invalidtoken',
            'message': 'Invalid token - token not found',
          };

      await expectLater(
        () => MoodleWebApiConnector.addDiscussionPost(
            postId: 900, subject: 's', message: 'm'),
        throwsA(isA<MoodleApiException>()),
      );
      expect(errors.single.errorcode, 'invalidtoken');
      expect(errors.single.isInvalidToken, isTrue);
    });
  });

  group('站台沒開放回覆那一支時', () {
    test('canPostToForum 為 false，而且一個請求都不送', () async {
      var calls = 0;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async {
        calls++;
        return const {};
      };
      // functions[] 有東西（knowsWsFunctions 為真）但沒有這一支。
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(functions: [
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.discussionPostsFunction,
            version: '4.5'),
      ]);

      expect(MoodleWebApiConnector.canPostToForum, isFalse);
      await expectLater(
        () => MoodleWebApiConnector.addDiscussionPost(
            postId: 900, subject: 's', message: 'm'),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.skippedBeforeRequest, 'skipped', isTrue)),
      );
      expect(calls, 0);
    });

    test('site_info 還沒載入時 fail-open', () {
      expect(MoodleWebApiConnector.canPostToForum, isTrue);
    });
  });

  group('accessOf', () {
    test('36 個 can* 全部讀得到，**沒有 caneditownpost 這個欄位**', () {
      final raw = loadMoodleForumFixture('get_forum_access_information');
      // access.php 沒有 mod/forum:editownpost 這個 capability：能不能編輯自己
      // 的貼文只有 post_exporter 的 capabilities.edit 答得出來。
      expect(raw.containsKey('caneditownpost'), isFalse);
      // 名字本身以 can 開頭的那五個會攤成雙 can，照著文件手打很容易打錯。
      expect(raw.containsKey('cancanposttomygroups'), isTrue);

      final access = MoodleWebApiConnector.accessOf(raw);
      expect(access!.cancreateattachment, isTrue);
      expect(access.candeleteownpost, isTrue);
      expect(access.canreplypost, isTrue);
      expect(access.canstartdiscussion, isTrue);
    });

    test('欄位缺席 → null＝不知道，不是 false', () {
      final access = MoodleWebApiConnector.accessOf(const {'warnings': []});

      expect(access!.cancreateattachment, isNull);
      expect(access.candeleteownpost, isNull);
    });

    test('形狀不對回 null', () {
      expect(MoodleWebApiConnector.accessOf(null), isNull);
      expect(MoodleWebApiConnector.accessOf('[]'), isNull);
    });
  });

  group('postForEditOf', () {
    test('回的是**原文**與抓取當下的 capabilities.edit', () {
      final edit = fixturePostForEdit();

      expect(edit.id, 950);
      expect(edit.canEdit, isTrue);
      expect(edit.rawFormat, 1);
      // 原文原封不動：沒有經過 _normalizePost，也沒有換掉 @@PLUGINFILE@@。
      expect(edit.rawMessage, '謝謝老師！<br>我會準時到。');
      // subject 進純文字 sink，實體要還原。
      expect(edit.subject, 'Re: 期中考 & 補考公告');
    });

    test('含 @@PLUGINFILE@@ 的原文原樣回來——由 util 的 round-trip 述詞去擋', () {
      final edit = fixturePostForEdit('get_discussion_post_rich');

      expect(edit.rawMessage, contains('@@PLUGINFILE@@'));
    });

    test('沒有 post、或 id 不是數字 → null（呼叫端當成失敗）', () {
      expect(
          MoodleWebApiConnector.postForEditOf(const {'warnings': []}), isNull);
      expect(
          MoodleWebApiConnector.postForEditOf(const {
            'post': {'subject': 'x'}
          }),
          isNull);
    });
  });

  group('getPostForEdit', () {
    test('要的是資料庫原文：raw=true、filter=false、fileurl=false', () async {
      Map<String, dynamic>? sent;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent = Map<String, dynamic>.from(parameter.data as Map);
        return loadMoodleForumFixture('get_discussion_post');
      };

      await MoodleWebApiConnector.getPostForEdit(950);

      expect(sent!['wsfunction'], MoodleWebApiConnector.discussionPostFunction);
      expect(sent!['postid'], '950');
      // filter 會把 filter plugin 的產物寫死進原文，fileurl 會把
      // @@PLUGINFILE@@ 換成絕對網址——兩者原樣送回伺服器就是永久污染。
      expect(sent!['moodlewssettingraw'], 'true');
      expect(sent!['moodlewssettingfilter'], 'false');
      expect(sent!['moodlewssettingfileurl'], 'false');
    });
  });

  group('prepareForumDraftArea', () {
    test('送 area=attachment、draftitemid=0；filestokeep 空的時候整個鍵都不出現', () async {
      Map<String, dynamic>? sent;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent = Map<String, dynamic>.from(parameter.data as Map);
        return loadMoodleForumFixture('prepare_draft_area_for_post');
      };

      final area =
          await MoodleWebApiConnector.prepareForumDraftArea(postId: 950);

      expect(area.draftitemid, 884411);
      expect(
          sent!['wsfunction'], MoodleWebApiConnector.prepareDraftAreaFunction);
      expect(sent!['postid'], '950');
      expect(sent!['area'], 'attachment');
      expect(sent!['draftitemid'], '0');
      // 空的 filestokeep ＝全部保留，所以連鍵都不送。
      expect(sent!.keys.join(','), isNot(contains('filestokeep')));
    });

    test('area: post 時送 area=post，而且 draftitemid 一樣是 0', () async {
      Map<String, dynamic>? sent;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent = Map<String, dynamic>.from(parameter.data as Map);
        return loadMoodleForumFixture('prepare_draft_area_for_post_inline');
      };

      final area = await MoodleWebApiConnector.prepareForumDraftArea(
          postId: 951, area: MoodleWebApiConnector.forumDraftAreaPost);

      expect(sent!['area'], 'post');
      expect(sent!['postid'], '951');
      expect(sent!['draftitemid'], '0');
      // 內嵌那一區送非空的 filestokeep 會把要保護的圖片刪掉。
      expect(sent!.keys.join(','), isNot(contains('filestokeep')));
      expect(area.draftitemid, 990011);
    });

    test('messagetext 落地了——它是 draft 網址前綴唯一的來源', () {
      final area = fixtureDraftArea('prepare_draft_area_for_post_inline');

      expect(area.messagetext, contains('/draftfile.php/'));
      expect(area.messagetext, contains('/user/draft/990011/'));
    });

    test('area=attachment 的 messagetext 是 null → 空字串，其他欄位不受影響', () {
      final area = fixtureDraftArea();

      expect(area.messagetext, '');
      expect(area.draftitemid, 884411);
      expect(area.maxbytes, 262144);
      expect(area.maxfiles, 3);
    });

    test('filestokeep 逐筆展開成 filename/filepath', () async {
      Map<String, dynamic>? sent;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent = Map<String, dynamic>.from(parameter.data as Map);
        return loadMoodleForumFixture('prepare_draft_area_for_post');
      };

      await MoodleWebApiConnector.prepareForumDraftArea(
        postId: 950,
        filesToKeep: const [(filename: 'slides.pdf', filepath: '/')],
      );

      expect(sent!['filestokeep[0][filename]'], 'slides.pdf');
      expect(sent!['filestokeep[0][filepath]'], '/');
    });

    test('files[] 的網址欄位是 fileurl（external_files），不是貼文附件的 url', () {
      final area = fixtureDraftArea();

      expect(area.files.first.filename, 'slides.pdf');
      expect(area.files.first.fileurl, contains('/draftfile.php/'));
      expect(area.files.first.mimetype, 'application/pdf');
    });

    test('areaoptions 的 value 是字串，maxbytes 是伺服器解析過的真值', () {
      final area = fixtureDraftArea();

      expect(area.maxbytes, 262144);
      expect(area.maxfiles, 3);
    });

    test('沒有可用的 draftitemid → 丟例外，不可以拿一個假的去覆蓋附件', () async {
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async => const {'warnings': []};

      await expectLater(
        () => MoodleWebApiConnector.prepareForumDraftArea(postId: 950),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'couldnotadd')),
      );
    });

    test('can_edit_post 為假時伺服器丟 noviewdiscussionspermission，原樣往上拋', () async {
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async => const {
            'exception': 'moodle_exception',
            'errorcode': 'noviewdiscussionspermission',
            'message': 'You cannot view discussions in this forum',
          };

      await expectLater(
        () => MoodleWebApiConnector.prepareForumDraftArea(postId: 950),
        throwsA(isA<MoodleApiException>().having(
            (e) => e.errorcode, 'errorcode', 'noviewdiscussionspermission')),
      );
    });
  });

  group('updateDiscussionPost', () {
    test('**不含 topreferredformat**——那個選項在這一支會回 errorinvalidparam', () async {
      Map<String, dynamic>? sent;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent = Map<String, dynamic>.from(parameter.data as Map);
        return loadMoodleForumFixture('update_discussion_post_ok');
      };

      await MoodleWebApiConnector.updateDiscussionPost(
          postId: 950,
          subject: '改過的標題',
          message: '改過的內文',
          messageFormat: MoodleForumUtils.formatHtml);

      expect(sent!['wsfunction'],
          MoodleWebApiConnector.updateDiscussionPostFunction);
      expect(sent!['postid'], '950');
      expect(sent!['subject'], '改過的標題');
      expect(sent!['message'], '改過的內文');
      // 原文的 format 原樣送回去。寫死 FORMAT_PLAIN 會把一篇 FORMAT_HTML
      // 貼文永久改成純文字，而這一支不吃 topreferredformat，救不回來。
      expect(sent!['messageformat'], '1');
      expect(sent!.keys.join(','), isNot(contains('topreferredformat')));
      // 不送 attachmentsid ＝既有附件原封不動。
      expect(sent!.keys.join(','), isNot(contains('attachmentsid')));
    });

    test('attachmentsid 只在該送時才出現，而且是 options[0]', () async {
      Map<String, dynamic>? sent;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent = Map<String, dynamic>.from(parameter.data as Map);
        return loadMoodleForumFixture('update_discussion_post_ok');
      };

      await MoodleWebApiConnector.updateDiscussionPost(
          postId: 950,
          subject: 's',
          message: 'm',
          messageFormat: MoodleForumUtils.formatPlain,
          attachmentsId: 884411);

      expect(sent!['options[0][name]'], 'attachmentsid');
      expect(sent!['options[0][value]'], '884411');
    });

    test('只送 inlineattachmentsid 時它是 options[0]——索引不可以留洞', () async {
      Map<String, dynamic>? sent;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent = Map<String, dynamic>.from(parameter.data as Map);
        return loadMoodleForumFixture('update_discussion_post_ok');
      };

      await MoodleWebApiConnector.updateDiscussionPost(
          postId: 950,
          subject: 's',
          message: 'm',
          messageFormat: MoodleForumUtils.formatHtml,
          inlineAttachmentsId: 771122);

      expect(sent!['options[0][name]'], 'inlineattachmentsid');
      expect(sent!['options[0][value]'], '771122');
      expect(sent!.keys.join(','), isNot(contains('options[1]')));
    });

    test('兩個 id 都送時索引是連號的 0 / 1', () async {
      Map<String, dynamic>? sent;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent = Map<String, dynamic>.from(parameter.data as Map);
        return loadMoodleForumFixture('update_discussion_post_ok');
      };

      await MoodleWebApiConnector.updateDiscussionPost(
          postId: 950,
          subject: 's',
          message: 'm',
          messageFormat: MoodleForumUtils.formatHtml,
          attachmentsId: 884411,
          inlineAttachmentsId: 990011);

      expect(sent!['options[0][name]'], 'attachmentsid');
      expect(sent!['options[0][value]'], '884411');
      expect(sent!['options[1][name]'], 'inlineattachmentsid');
      expect(sent!['options[1][value]'], '990011');
      // topreferredformat 在這一支會回 errorinvalidparam。
      expect(sent!.keys.join(','), isNot(contains('topreferredformat')));
    });

    test('inlineattachmentsid <= 0 直接拒收——送 0 會把貼文裡的圖片全部刪光', () async {
      var called = false;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async {
        called = true;
        return loadMoodleForumFixture('update_discussion_post_ok');
      };

      for (final bad in [0, -1]) {
        await expectLater(
          () => MoodleWebApiConnector.updateDiscussionPost(
              postId: 950,
              subject: 's',
              message: 'm',
              messageFormat: MoodleForumUtils.formatHtml,
              inlineAttachmentsId: bad),
          throwsA(isA<ArgumentError>()),
        );
      }
      // 不可以靜靜改成「不送」：那會退回 IGNORE_FILE_MERGE，把 draftfile
      // 絕對網址原樣存進資料庫。
      expect(called, isFalse);
    });

    test('cannotupdatepost 一路往上拋', () async {
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async =>
          loadMoodleForumFixture('update_discussion_post_cannotupdate');

      await expectLater(
        () => MoodleWebApiConnector.updateDiscussionPost(
            postId: 950,
            subject: 's',
            message: 'm',
            messageFormat: MoodleForumUtils.formatHtml),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'cannotupdatepost')),
      );
    });

    test('status 不是 true 一律當失敗——證明不了寫入發生過就是失敗', () async {
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost =
          (_) async => const {'status': false, 'warnings': []};

      await expectLater(
        () => MoodleWebApiConnector.updateDiscussionPost(
            postId: 950,
            subject: 's',
            message: 'm',
            messageFormat: MoodleForumUtils.formatHtml),
        throwsA(isA<MoodleApiException>()),
      );
    });
  });

  group('deleteForumPost', () {
    test('只送 postid，status: true 才算成功', () async {
      Map<String, dynamic>? sent;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent = Map<String, dynamic>.from(parameter.data as Map);
        return loadMoodleForumFixture('delete_post_ok');
      };

      await MoodleWebApiConnector.deleteForumPost(950);

      expect(sent!['wsfunction'], MoodleWebApiConnector.deletePostFunction);
      expect(sent!['postid'], '950');
    });

    test('couldnotdeletereplies 一路往上拋（module 是 forum）', () async {
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async =>
          loadMoodleForumFixture('delete_post_couldnotdeletereplies');

      await expectLater(
        () => MoodleWebApiConnector.deleteForumPost(950),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'couldnotdeletereplies')),
      );
    });

    test('couldnotdeleteratings 的 module 是 rating，不是 forum', () async {
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async =>
          loadMoodleForumFixture('delete_post_couldnotdeleteratings');

      await expectLater(
        () => MoodleWebApiConnector.deleteForumPost(950),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'couldnotdeleteratings')),
      );
    });

    test('回不出 status（捕獲入口頁之類）也算失敗', () async {
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async => '<html>captive portal</html>';

      await expectLater(
        () => MoodleWebApiConnector.deleteForumPost(950),
        throwsA(isA<MoodleApiException>()),
      );
    });
  });

  group('帶附件的兩支新增', () {
    test('addDiscussionPost 的 attachmentsid 是 options[1]，topreferredformat 還在',
        () async {
      Map<String, dynamic>? sent;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent = Map<String, dynamic>.from(parameter.data as Map);
        return loadMoodleForumFixture('add_discussion_post_with_attachment');
      };

      final post = await MoodleWebApiConnector.addDiscussionPost(
          postId: 900, subject: 's', message: 'm', attachmentsId: 884411);

      expect(sent!['options[0][name]'], 'topreferredformat');
      expect(sent!['options[1][name]'], 'attachmentsid');
      expect(sent!['options[1][value]'], '884411');
      // 回應自帶伺服器實際收下的附件，事後驗證不必再打一趟。
      expect(
          post.attachments.map((f) => f.filename), ['slides.pdf', 'note.txt']);
    });

    test('伺服器靜靜丟掉一個附件：回應是成功、warnings 是空的，只有比對看得出來', () async {
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async =>
          loadMoodleForumFixture('add_discussion_post_attachment_dropped');

      final post = await MoodleWebApiConnector.addDiscussionPost(
          postId: 900, subject: 's', message: 'm', attachmentsId: 884411);

      // 送兩個、收下一個，而且伺服器一句話都沒說。
      expect(post.attachments.map((f) => f.filename), ['slides.pdf']);
      expect(
        MoodleForumEditUtils.missingAttachments(
            ['slides.pdf', 'note.txt'], post.attachments),
        ['note.txt'],
      );
    });

  });

  group('upload.php 的錯誤形狀', () {
    test('filenameexist 是**陣列裡的一個元素**，HTTP 照樣 200', () {
      expect(
        () => MoodleWebApiConnector.draftFileOf(
            loadMoodleForumListFixture('upload_filenameexist')),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'filenameexist')),
      );
    });
  });

  group('編輯後重讀', () {
    test('附件走 stored_file_exporter，欄位是 url（不是 draft 區的 fileurl）', () {
      final edit = fixturePostForEdit('get_discussion_post_with_attachments');

      expect(
          edit.attachments.map((f) => f.filename), ['slides.pdf', 'note.txt']);
      expect(edit.attachments.first.url, contains('/pluginfile.php/'));
      // 少了一個就是伺服器靜靜丟掉了。
      expect(
        MoodleForumEditUtils.missingAttachments(
            ['slides.pdf', 'note.txt', 'extra.pdf'], edit.attachments),
        ['extra.pdf'],
      );
    });
  });

  group('五支新 function 的站台開關', () {
    test('functions[] 沒列出來時四個 getter 都是 false，而且一個請求都不送', () async {
      var calls = 0;
      MoodleWebApiConnector.wsToken = 'tok';
      MoodleWebApiConnector.wsPost = (_) async {
        calls++;
        return const {};
      };
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(functions: [
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.discussionPostsFunction,
            version: '4.5'),
      ]);

      expect(MoodleWebApiConnector.canEditForumPost, isFalse);
      expect(MoodleWebApiConnector.canDeleteForumPost, isFalse);
      expect(MoodleWebApiConnector.canPrepareForumDraftArea, isFalse);
      expect(MoodleWebApiConnector.canReadForumPost, isFalse);
      await expectLater(
        () => MoodleWebApiConnector.deleteForumPost(950),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.skippedBeforeRequest, 'skipped', isTrue)),
      );
      expect(calls, 0);
    });

    test('site_info 還沒載入時 fail-open', () {
      expect(MoodleWebApiConnector.canEditForumPost, isTrue);
      expect(MoodleWebApiConnector.canDeleteForumPost, isTrue);
      expect(MoodleWebApiConnector.canPrepareForumDraftArea, isTrue);
      expect(MoodleWebApiConnector.canReadForumPost, isTrue);
    });
  });
}
