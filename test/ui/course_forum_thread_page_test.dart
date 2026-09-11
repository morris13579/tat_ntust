import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_compose_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_rich_edit_page.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_post_block.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/result_view.dart';
import 'package:flutter_app/ui/components/tile/moodle_file_tile.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_thread_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_bottom_bar.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_composer_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_forum_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';
import '../helpers/finders.dart';

/// 討論串頁的畫面規格。貼文以快取 seed，離線所以不碰網路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  late RecordingUi ui;

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    ui = RecordingUi();
    TaskUiDelegate.instance = ui;
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
    MoodleRepository.instance = MoodleRepository();
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  final courseInfo = CourseInfoJson(
    main: CourseMainInfoJson(
        course: CourseMainJson(id: 'CS3001701', name: '作業系統')),
  );

  Discussions discussion() => fixtureDiscussions().discussions.first;

  Future<void> seedPosts(int discussionId, List<MoodleForumPost> posts) =>
      CacheStore.instance.write(
        CacheKey<List<MoodleForumPost>>(
          'cache_moodle_forum_posts',
          discussionId.toString(),
          decode: (json) => (json as List)
              .map((e) =>
                  MoodleForumPost.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
        ),
        posts,
      );

  Future<void> pump(
    WidgetTester tester, {
    Discussions? d,
    List<(String, String)>? opened,
    bool readOnly = false,
    List<int>? changed,
  }) async {
    // ListView 是懶載入的，超出視窗的段落根本不會被建出來；把視窗拉高，
    // 整頁都在畫面上。
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(GetMaterialApp(
      home: CourseForumThreadPage(
        courseInfo,
        discussionId: (d ?? discussion()).discussion,
        title: (d ?? discussion()).name,
        fallbackDiscussion: d ?? discussion(),
        readOnly: readOnly,
        onDiscussionChanged: () => changed?.add(1),
        openWebView: (title, url) async => opened?.add((title, url)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('四篇貼文：作者依 DFS 順序，只有第一篇印標題', (tester) async {
    await seedPosts(7701, fixturePosts());

    await pump(tester);

    expect(find.byType(ForumPostBlock), findsNWidgets(4));
    // 王老師（根）→ 陳同學 → 王老師 → 已刪除那篇（作者是空的）。
    double y(Finder f) => tester.getTopLeft(f).dy;
    expect(y(find.text('陳同學')), lessThan(y(find.text('不明的發文者'))));

    // 只有第一篇印 subject，回覆的「Re: …」不重複印。
    expect(find.text('期中考 & 補考公告'), findsNWidgets(2),
        reason: 'AppBar 一個、第一篇的子標題一個');
    expect(find.textContaining('Re: '), findsNothing);

    expect(find.textContaining('期中考範圍如圖', findRichText: true), findsOneWidget);
    expect(find.textContaining('可以帶計算機嗎', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppBar 標題是公告名稱', (tester) async {
    await seedPosts(7701, fixturePosts());

    await pump(tester);

    expect(
      find.descendant(
          of: find.byType(AppBar), matching: find.text('期中考 & 補考公告')),
      findsOneWidget,
    );
  });

  testWidgets('縮排：回覆有左邊距，巢狀那一篇更深', (tester) async {
    await seedPosts(7701, fixturePosts());

    await pump(tester);

    /// 每一則的最外層縮排是 `EdgeInsets.only(left:)`；ListView 自己的 padding
    /// 有上下邊所以不會被選中。
    double indentOf(String body) {
      final block = find
          .ancestor(
            of: find.textContaining(body, findRichText: true),
            matching: find.byWidgetPredicate((w) =>
                w is Padding &&
                w.padding is EdgeInsets &&
                (w.padding as EdgeInsets).top == 0 &&
                (w.padding as EdgeInsets).right == 0 &&
                (w.padding as EdgeInsets).bottom == 0),
          )
          .last;
      return (tester.widget<Padding>(block).padding as EdgeInsets).left;
    }

    expect(indentOf('期中考範圍如圖'), 0, reason: '根貼文不縮排');
    expect(indentOf('可以帶計算機嗎'), greaterThan(0));
    expect(indentOf('不能用可程式化的'), greaterThan(indentOf('可以帶計算機嗎')));
  });

  testWidgets('已刪除的貼文：畫刪除提示、沒有時間字串', (tester) async {
    await seedPosts(7701, fixturePosts());

    await pump(tester);

    expect(find.text('這則貼文已被刪除'), findsOneWidget);
    expect(find.text('此貼文已被刪除'), findsNothing,
        reason: '伺服器語系的字串不直接顯示，改用自己的 l10n');
  });

  testWidgets('第一篇的附件畫成檔案列', (tester) async {
    await seedPosts(7701, fixturePosts());

    await pump(tester);

    expect(find.text('附件'), findsOneWidget);
    expect(find.widgetWithText(MoodleFileTile, 'slides.pdf'), findsOneWidget);
    expect(find.byIcon(LucideIconsThin.download), findsOneWidget);
  });

  testWidgets('抓不到回覆：仍然畫出公告本文加就地重試，不是整頁錯誤', (tester) async {
    await pump(tester);

    expect(find.byType(InlineErrorView), findsOneWidget);
    // 清單那一列本身就是第一篇貼文，內容還在。
    expect(
        find.textContaining('期中考於下週三舉行', findRichText: true), findsOneWidget);
    expect(find.text('王老師'), findsOneWidget);
    // 子標題走 discussion.subject，實體同樣要在 connector 就還原掉。
    expect(find.text('期中考 & 補考公告'), findsNWidgets(2),
        reason: 'AppBar 的 name 與卡片子標題的 subject');
    expect(find.textContaining('&amp;'), findsNothing);
    expect(
        find.widgetWithText(MoodleFileTile, 'exam_scope.pdf'), findsOneWidget);
  });

  testWidgets('本文的連結交給注入的 openWebView', (tester) async {
    final opened = <(String, String)>[];
    final posts = [
      MoodleForumPost(
        id: 900,
        subject: '公告',
        message: '<p><a href="https://example.com/x">safe</a></p>',
        discussionid: 7701,
        timecreated: 1756900000,
        author: MoodleForumAuthor(fullname: '王老師'),
      ),
    ];
    await seedPosts(7701, posts);

    await pump(tester, opened: opened);

    final link = find.text('safe', findRichText: true);
    await tester.tapAt(tester.getTopLeft(link) + const Offset(6, 8));
    await tester.pumpAndSettle();

    expect(opened, [('期中考 & 補考公告', 'https://example.com/x')]);
  });

  MoodleForumPost postWith({
    required int id,
    bool? reply,
    bool edit = false,
    bool delete = false,
    int? parentid,
    String message = '<p>內容</p>',
    bool isdeleted = false,
    int? timemodified,
    List<MoodleForumFile> attachments = const [],
  }) {
    final p = MoodleForumPost(
      id: id,
      subject: '主題',
      message: message,
      discussionid: 7701,
      hasparent: parentid != null,
      parentid: parentid,
      timecreated: 1756900000,
      timemodified: timemodified,
      isdeleted: isdeleted,
      attachments: [...attachments],
      author: MoodleForumAuthor(fullname: '陳同學'),
    );
    if (reply != null) {
      p.capabilities =
          MoodleForumPostCapabilities(reply: reply, edit: edit, delete: delete);
    }
    return p;
  }

  /// 站台把 functions[] 回報成「沒有 add_discussion_post」。
  void siteWithoutPosting() {
    MoodleWebApiConnector.siteInfo = MoodleProfileEntity(functions: [
      MoodleProfileFunctions(
          name: MoodleWebApiConnector.discussionPostsFunction, version: '4.5'),
    ]);
  }

  /// 卡片裡的「回覆」是 InkWell + Row，不是 TextButton：主題給每一顆鈕
  /// 44 的最小高度與 16 的側邊留白，塞在貼文卡片裡就是一塊很大的空白。
  Finder replyButton() => find.ancestor(
      of: find.text(R.current.forumReply), matching: find.byType(InkWell));

  Finder composerBar() => find.byType(ForumComposerBar);

  /// `IconButton` 自己 build 出 `Tooltip`，所以 tooltip 是它的子孫。
  Finder sendButton() => find.ancestor(
      of: find.byTooltip(R.current.forumSend),
      matching: find.byType(IconButton));

  Finder actionsButton() => find.ancestor(
      of: find.byTooltip(R.current.forumPostActions),
      matching: find.byType(IconButton));

  testWidgets('capabilities.reply 為 true 的才有回覆鈕；已刪除與沒有 capabilities 的都沒有',
      (tester) async {
    await seedPosts(7701, fixturePosts());

    await pump(tester);

    // fixture 的 900 / 901 / 902 可回覆，已刪除的 903 不行。
    expect(replyButton(), findsNWidgets(3));
    expect(composerBar(), findsOneWidget);
  });

  testWidgets('完全沒有 capabilities 區塊（舊快取）→ 一顆回覆鈕都不畫，底部改成說明列', (tester) async {
    await seedPosts(7701, [postWith(id: 900)]);

    await pump(tester);

    expect(replyButton(), findsNothing);
    expect(composerBar(), findsNothing);
    expect(find.byType(ForumNoticeBar), findsOneWidget);
    expect(find.text(R.current.forumThreadLocked), findsOneWidget);
  });

  testWidgets('站台沒開放 add_discussion_post 時整排回覆鈕與回覆列都不畫', (tester) async {
    siteWithoutPosting();
    await seedPosts(7701, fixturePosts());

    await pump(tester);

    expect(replyButton(), findsNothing);
    expect(composerBar(), findsNothing);
  });

  testWidgets('沒有任何一篇能回覆時：底部是說明列加網頁入口，不是一顆會失敗的鈕', (tester) async {
    final opened = <(String, String)>[];
    await seedPosts(7701, [postWith(id: 900, reply: false)]);

    await pump(tester, opened: opened);

    expect(find.text(R.current.forumThreadLocked), findsOneWidget);
    final webButton = buttonWithText(R.current.forumOpenInWeb);
    expect(webButton, findsOneWidget);

    await tester.tap(webButton);
    await tester.pumpAndSettle();

    expect(opened.single.$2, contains('/mod/forum/discuss.php?d=7701'));
  });

  testWidgets('唯讀的公告區：不能回覆時整條列都不畫，不掛一個網頁也走不通的出口', (tester) async {
    await seedPosts(7701, [postWith(id: 900, reply: false)]);

    await pump(tester, readOnly: true);

    // 網頁版走的是同一個 replynews，那條列只會給一個一樣被拒的出口。
    expect(find.byType(ForumNoticeBar), findsNothing);
    expect(find.text(R.current.forumThreadLocked), findsNothing);
    expect(composerBar(), findsNothing);
  });

  testWidgets('唯讀的公告區：老師還是有回覆列——收起來的只有那條說明', (tester) async {
    await seedPosts(7701, [postWith(id: 900, reply: true)]);

    await pump(tester, readOnly: true);

    expect(composerBar(), findsOneWidget);
  });

  testWidgets('抓不到貼文（Failed）時底部一條列都不畫——不知道能不能回覆就不要畫', (tester) async {
    await pump(tester);

    expect(composerBar(), findsNothing);
    expect(find.byType(ForumNoticeBar), findsNothing);
  });

  testWidgets('Stale（離線／重抓失敗）時回覆列照畫——那時使用者必須能繼續講話', (tester) async {
    MoodleRepository.instance = _FakeRepo()..reloadAlwaysFails = true;
    await seedPosts(7701, fixturePosts());

    await pump(tester);

    expect(composerBar(), findsOneWidget);
  });

  testWidgets('Stale 的橫幅按重新整理：打到一半的草稿還在——那條列不可以被拆掉', (tester) async {
    final repo = _FakeRepo()..reloadAlwaysFails = true;
    MoodleRepository.instance = repo;
    await seedPosts(7701, fixturePosts());

    await pump(tester);
    await tester.enterText(
        find.descendant(of: composerBar(), matching: find.byType(TextField)),
        '打到一半的回覆');
    await tester.pump();

    repo.holdReload = Completer<void>();
    await tester.tap(find.descendant(
        of: find.byType(ResultView<List<MoodleForumPost>>),
        matching: find.widgetWithText(TextButton, R.current.refresh)));
    await tester.pump();

    // 重抓的那幾格：這裡把 posts 清成 null 就會連 State 一起拆掉，草稿與
    // 已經挑好的附件跟著消失，而且返回鍵還會為那份不存在的草稿攔一次路。
    expect(composerBar(), findsOneWidget);
    expect(find.text('打到一半的回覆'), findsOneWidget);

    repo.holdReload!.complete();
    await tester.pumpAndSettle();

    expect(find.text('打到一半的回覆'), findsOneWidget);
  });

  group('回覆（不換頁）', () {
    testWidgets('鍵盤打開時回覆列被抬到鍵盤上方，不是留在畫面最底被蓋住', (tester) async {
      await seedPosts(7701, fixturePosts());

      await pump(tester);

      // pump 裡把視窗設成 800×3000（dpr 1）。
      const height = 3000.0;
      const keyboard = 1000.0;
      expect(tester.getRect(composerBar()).bottom, height,
          reason: '鍵盤還沒開的時候它就貼在最底下');

      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      // 這一條就是 defect 7：`bottomNavigationBar` 是照整個畫面高度釘的，
      // 放在那裡的話這個值會還是 3000（也就是整條在鍵盤底下）。
      expect(tester.getRect(composerBar()).bottom,
          lessThanOrEqualTo(height - keyboard));
      expect(composerBar(), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('點某一篇的回覆：目標列出現、那一篇被框起來', (tester) async {
      await seedPosts(7701, fixturePosts());

      await pump(tester);
      await tester.tap(replyButton().at(1));
      await tester.pumpAndSettle();

      expect(find.text(sprintf(R.current.forumReplyingTo, ['陳同學'])),
          findsOneWidget);
      // 不換頁：討論串還在。
      expect(find.byType(CourseForumThreadPage), findsOneWidget);
      expect(find.byType(CourseForumComposePage), findsNothing);
    });

    testWidgets('送出成功：新貼文併進討論串，**不吐「已送出」**（那則回覆就在眼前）', (tester) async {
      final repo = _FakeRepo()
        ..nextReply = Ok(
            ForumReplyOutcome(postWith(id: 950, reply: true, parentid: 900)));
      MoodleRepository.instance = repo;
      await seedPosts(7701, fixturePosts());

      await pump(tester);
      await tester.enterText(find.byType(TextField), '謝謝老師');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pumpAndSettle();

      expect(repo.replyCalls, 1);
      expect(find.byType(ForumPostBlock), findsNWidgets(5));
      expect(ui.toasts, isNot(contains(R.current.forumSendDoneRefreshFailed)));
      // 送出成功要清空，鍵盤與焦點留著。
      expect(find.text('謝謝老師'), findsNothing);
    });

    testWidgets('送出成功但重抓失敗：回覆留在畫面上、畫舊資料橫幅，並說一句沒有重新載入', (tester) async {
      final repo = _FakeRepo()
        ..nextReply =
            Ok(ForumReplyOutcome(postWith(id: 950, reply: true, parentid: 900)))
        ..reloadFails = true;
      MoodleRepository.instance = repo;
      await seedPosts(7701, fixturePosts());

      await pump(tester);
      await tester.enterText(find.byType(TextField), '謝謝老師');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pumpAndSettle();

      expect(find.byType(ForumPostBlock), findsNWidgets(5),
          reason: '寫入成功了，剛送出的那一則不可以消失');
      expect(find.byType(InlineErrorView), findsNothing, reason: '不是錯誤畫面');
      expect(ui.toasts, contains(R.current.forumSendDoneRefreshFailed));
    });

    testWidgets('附件被伺服器靜靜丟掉：貼文照樣進畫面，但明講少了哪一個', (tester) async {
      final repo = _FakeRepo()
        ..nextReply = Ok(ForumReplyOutcome(
            postWith(id: 950, reply: true, parentid: 900),
            warning: sprintf(R.current.forumAttachmentMissing, ['note.txt'])));
      MoodleRepository.instance = repo;
      await seedPosts(7701, fixturePosts());

      await pump(tester);
      await tester.enterText(find.byType(TextField), '謝謝老師');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pumpAndSettle();

      expect(find.byType(ForumPostBlock), findsNWidgets(5),
          reason: '貼文真的發出去了，不可以報成失敗');
      expect(ui.toasts.last, contains('note.txt'));
    });

    testWidgets('送出失敗：留在原地、文字還在，吐對應好的訊息', (tester) async {
      MoodleRepository.instance = _FakeRepo()
        ..nextReply = Failed(FetchFailed(R.current.forumErrorNoPermission));
      await seedPosts(7701, fixturePosts());

      await pump(tester);
      await tester.enterText(find.byType(TextField), '謝謝老師');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pumpAndSettle();

      expect(find.text('謝謝老師'), findsOneWidget);
      expect(ui.toasts, contains(R.current.forumErrorNoPermission));
    });
  });

  group('自己的貼文', () {
    testWidgets('capabilities.edit / delete 都是 false → 沒有 ⋯', (tester) async {
      await seedPosts(7701, [postWith(id: 900, reply: true)]);

      await pump(tester);

      expect(actionsButton(), findsNothing);
    });

    testWidgets('edit 為 true → 有 ⋯，選單裡有編輯', (tester) async {
      await seedPosts(7701, [postWith(id: 900, reply: true, edit: true)]);
      MoodleRepository.instance = _FakeRepo();

      await pump(tester);

      expect(actionsButton(), findsOneWidget);
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();

      expect(find.text(R.current.forumEditPost), findsOneWidget);
      expect(find.text(R.current.forumDeletePost), findsNothing);
    });

    testWidgets('Stale 時看不到編輯與刪除——能力旗標是快照，過期了就開始說謊', (tester) async {
      MoodleRepository.instance = _FakeRepo()..reloadAlwaysFails = true;
      await seedPosts(
          7701, [postWith(id: 900, reply: true, edit: true, delete: true)]);

      await pump(tester);

      expect(actionsButton(), findsNothing);
    });

    testWidgets('站台沒開 update_discussion_post → 選單裡沒有編輯', (tester) async {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(functions: [
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.discussionPostsFunction,
            version: '4.5'),
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.addDiscussionPostFunction,
            version: '4.5'),
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.deletePostFunction, version: '4.5'),
      ]);
      MoodleRepository.instance = _FakeRepo();
      await seedPosts(
          7701, [postWith(id: 900, reply: true, edit: true, delete: true)]);

      await pump(tester);
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();

      expect(find.text(R.current.forumEditPost), findsNothing);
      expect(find.text(R.current.forumDeletePost), findsOneWidget);
    });

    testWidgets('有附件而站台沒開 prepare_draft_area_for_post → 選單裡沒有編輯',
        (tester) async {
      // 那時唯一剩下的路是「不送 attachmentsid」，而那會把主題清單的迴紋針
      // 清掉。與其存檔那一刻才拒絕，不如一開始就不給入口。
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(functions: [
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.discussionPostsFunction,
            version: '4.5'),
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.addDiscussionPostFunction,
            version: '4.5'),
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.discussionPostFunction, version: '4.5'),
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.updateDiscussionPostFunction,
            version: '4.5'),
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.deletePostFunction, version: '4.5'),
      ]);
      MoodleRepository.instance = _FakeRepo();
      await seedPosts(7701, [
        postWith(
          id: 900,
          reply: true,
          edit: true,
          delete: true,
          attachments: [MoodleForumFile(filename: 'slides.pdf')],
        ),
      ]);

      await pump(tester);
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();

      expect(find.text(R.current.forumEditPost), findsNothing);
      expect(find.text(R.current.forumDeletePost), findsOneWidget);
    });

    testWidgets('有回覆時刪除項是停用的，並附一句理由', (tester) async {
      MoodleRepository.instance = _FakeRepo();
      await seedPosts(7701, [
        postWith(id: 900, reply: true, delete: true),
        postWith(id: 901, reply: true, parentid: 900),
      ]);

      await pump(tester);
      await tester.tap(actionsButton().first);
      await tester.pumpAndSettle();

      expect(find.text(R.current.forumCannotDeleteHasReplies), findsOneWidget);
      final tile = tester.widget<ListTile>(find.ancestor(
          of: find.text(R.current.forumDeletePost),
          matching: find.byType(ListTile)));
      expect(tile.enabled, isFalse);
    });
  });

  group('編輯的守門', () {
    testWidgets('原文含 <img> → 推所見即所得編輯頁，**不再出現任何對話框**', (tester) async {
      MoodleRepository.instance = _FakeRepo()
        ..nextEditSource = fixturePostForEdit('get_discussion_post_rich');
      await seedPosts(7701, [postWith(id: 900, reply: true, edit: true)]);

      await pump(tester);
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.forumEditPost));
      await tester.pumpAndSettle();

      expect(find.byType(CourseForumRichEditPage), findsOneWidget);
      expect(find.byType(CourseForumComposePage), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('FORMAT_MARKDOWN → 純文字框，內容是**原始碼本身**，不套 htmlToPlain',
        (tester) async {
      const markdown = '## 標題\n\na &amp; b';
      final source = fixturePostForEdit();
      MoodleRepository.instance = _FakeRepo()
        ..nextEditSource = (
          id: source.id,
          subject: source.subject,
          rawMessage: markdown,
          rawFormat: 4,
          canEdit: true,
          attachments: source.attachments,
        );
      await seedPosts(7701, [postWith(id: 900, reply: true, edit: true)]);

      await pump(tester);
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.forumEditPost));
      await tester.pumpAndSettle();

      expect(find.byType(CourseForumComposePage), findsOneWidget);
      expect(find.byType(CourseForumRichEditPage), findsNothing);
      // `&amp;` 沒有被還原成 `&`：那會是一次使用者沒按過任何鍵的內容竄改。
      expect(find.text(markdown), findsOneWidget);
      // 這個框吃的是 Markdown 原始碼，`**粗體**` 打在這裡就會生效；
      // 底下那一行不可以還在叫人去網頁版做這件事。
      expect(find.text(R.current.forumMarkdownSource), findsOneWidget);
      expect(find.text(R.current.forumFormattingInWeb), findsNothing);
    });

    testWidgets('內嵌圖片：@@PLUGINFILE@@ 展開成帶憑證的網址推進所見即所得編輯頁', (tester) async {
      MoodleWebApiConnector.wsToken = '0f1e2d3c4b5a69788796a5b4c3d2e1f0';
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity();
      // 釘住「探測完成、站台不支援 tokenpluginfile」那一格。
      MoodleWebApiConnector.tokenPluginFileWorks = false;
      MoodleRepository.instance = _FakeRepo()
        ..nextEditSource = fixturePostForEdit('get_discussion_post_rich');
      final post = postWith(id: 900, reply: true, edit: true);
      // stored_file_exporter 真正回的形狀：pluginfile.php ＋ ?forcedownload=1。
      post.messageinlinefiles = [
        MoodleForumFile(
          filename: 'scope.png',
          filepath: '/',
          url: '${MoodleWebApiConnector.host}/pluginfile.php/8801/mod_forum'
              '/post/951/scope.png?forcedownload=1',
        ),
      ];
      await seedPosts(7701, [post]);

      await pump(tester);
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.forumEditPost));
      await tester.pumpAndSettle();

      final page = tester.widget<CourseForumRichEditPage>(
          find.byType(CourseForumRichEditPage));
      // 換不掉就是「使用者看到 alt 文字取代了自己的圖」。
      expect(page.initialHtml, isNot(contains('@@PLUGINFILE@@')));
      expect(
          page.initialHtml,
          contains('${MoodleWebApiConnector.host}/webservice/pluginfile.php'
              '/8801/mod_forum/post/951/scope.png?'));
      expect(page.initialHtml, contains('token='));
      expect(page.initialHtml, contains('<b>重要</b>'));
    });

    testWidgets('伺服器說已經不能編輯了 → 吐「已超過可以編輯的時間」，**不提網頁**', (tester) async {
      final source = fixturePostForEdit();
      MoodleRepository.instance = _FakeRepo()
        ..nextEditSource = (
          id: source.id,
          subject: source.subject,
          rawMessage: source.rawMessage,
          rawFormat: source.rawFormat,
          canEdit: false,
          attachments: source.attachments,
        );
      await seedPosts(7701, [postWith(id: 900, reply: true, edit: true)]);

      await pump(tester);
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.forumEditPost));
      await tester.pumpAndSettle();

      expect(ui.toasts, contains(R.current.forumEditWindowClosed));
      expect(find.byType(CourseForumComposePage), findsNothing);
      expect(find.byType(CourseForumRichEditPage), findsNothing);
    });

    testWidgets('拿不到原文 → 吐更新失敗，不推一頁空的編輯器', (tester) async {
      MoodleRepository.instance = _FakeRepo()..editSourceFails = true;
      await seedPosts(7701, [postWith(id: 900, reply: true, edit: true)]);

      await pump(tester);
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.forumEditPost));
      await tester.pumpAndSettle();

      expect(ui.toasts, contains(R.current.forumEditError));
      expect(find.byType(CourseForumComposePage), findsNothing);
    });

    testWidgets('都過了 → 推編輯頁，內文帶的是**原文**還原出來的純文字', (tester) async {
      MoodleRepository.instance = _FakeRepo()
        ..nextEditSource = fixturePostForEdit();
      await seedPosts(7701, [postWith(id: 900, reply: true, edit: true)]);

      await pump(tester);
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.forumEditPost));
      await tester.pumpAndSettle();

      expect(find.byType(CourseForumComposePage), findsOneWidget);
      expect(find.text('謝謝老師！\n我會準時到。'), findsOneWidget);
    });
  });

  group('刪除', () {
    testWidgets('刪回覆：確認框用一般文案，成功後那一列不見並重抓', (tester) async {
      final repo = _FakeRepo();
      MoodleRepository.instance = repo;
      await seedPosts(7701, [
        postWith(id: 900, reply: true),
        postWith(id: 901, reply: true, delete: true, parentid: 900),
      ]);

      await pump(tester);
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.forumDeletePost));
      await tester.pumpAndSettle();

      expect(find.text(R.current.forumDeletePostConfirm), findsOneWidget);
      await tester.tap(buttonWithText(R.current.sure));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls.single, (postId: 901, isTopicPost: false));
      expect(ui.toasts, contains(R.current.forumDeleteDone));
    });

    testWidgets('刪主文：確認框講清楚整串會消失，成功後 pop 回清單且**沒有**再重讀討論串', (tester) async {
      final repo = _FakeRepo();
      MoodleRepository.instance = repo;
      await seedPosts(7701, [postWith(id: 900, reply: true, delete: true)]);

      await pump(tester);
      final before = repo.reloadCalls;
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.forumDeletePost));
      await tester.pumpAndSettle();

      expect(find.text(R.current.forumDeleteTopicConfirm), findsOneWidget);
      await tester.tap(buttonWithText(R.current.sure));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls.single, (postId: 900, isTopicPost: true));
      expect(repo.reloadCalls, before,
          reason: '討論串已經不存在，再打 get_discussion_posts 會丟 PHP Error');
      expect(ui.toasts, contains(R.current.forumDeleteDone));
    });

    testWidgets('伺服器說有回覆不能刪：那句話自己站得住，而且不提網頁', (tester) async {
      MoodleRepository.instance = _FakeRepo()
        ..nextDelete =
            Failed(FetchFailed(R.current.forumCannotDeleteHasReplies));
      await seedPosts(7701, [postWith(id: 900, reply: true, delete: true)]);

      await pump(tester);
      await tester.tap(actionsButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(R.current.forumDeletePost));
      await tester.pumpAndSettle();
      await tester.tap(buttonWithText(R.current.sure));
      await tester.pumpAndSettle();

      expect(ui.toasts.last, R.current.forumCannotDeleteHasReplies);
      expect(ui.toasts, isNot(contains(R.current.forumDeleteDone)));
      expect(find.byType(CourseForumThreadPage), findsOneWidget);
    });
  });

  testWidgets('編輯過的貼文：時間後面接一句「已編輯」，不然討論串會默默改寫歷史', (tester) async {
    await seedPosts(7701, [
      postWith(id: 900, reply: true, timemodified: 1756990000),
    ]);

    await pump(tester);

    expect(find.textContaining(R.current.forumEdited), findsOneWidget);
  });
}

/// 只換掉真的會出去的那幾步；其餘（快取）走真的路徑。
class _FakeRepo extends MoodleRepository {
  Result<ForumReplyOutcome>? nextReply;
  Result<bool>? nextDelete;
  ForumPostEdit? nextEditSource;
  bool editSourceFails = false;
  bool reloadFails = false;
  bool reloadAlwaysFails = false;

  /// 打開時第一趟之後的重抓會停在這裡，讓測試看得到「重抓中」那幾格畫面。
  /// 真的網路來回本來就跨很多格，快取讀取快到一格都佔不到。
  Completer<void>? holdReload;
  int replyCalls = 0;
  int reloadCalls = 0;
  final deleteCalls = <({int postId, bool isTopicPost})>[];

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
    replyCalls++;
    return nextReply ?? Failed(FetchFailed(R.current.forumSendError));
  }

  @override
  Future<Result<bool>> deletePost({
    required int postId,
    required bool isTopicPost,
    required int discussionId,
  }) async {
    deleteCalls.add((postId: postId, isTopicPost: isTopicPost));
    return nextDelete ?? const Ok(true);
  }

  @override
  Future<ForumPostEdit?> fetchPostForEdit(int postId) async =>
      editSourceFails ? null : nextEditSource;

  @override
  Future<Result<ForumAttachPolicy>> getForumAttachPolicy({
    required String courseId,
    required int forumId,
  }) async =>
      const Ok(ForumAttachPolicy.off());

  @override
  Future<Result<List<MoodleForumPost>>> getDiscussionPosts(
      int discussionId) async {
    reloadCalls++;
    final gate = holdReload;
    if (gate != null && reloadCalls > 1) await gate.future;
    // 第一趟是進頁面時的載入，一律成功；之後那一趟才是「送出後的重抓」。
    if (reloadAlwaysFails || (reloadFails && reloadCalls > 1)) {
      final cached = await super.getDiscussionPosts(discussionId);
      final data = cached.dataOrNull;
      return data == null
          ? Failed<List<MoodleForumPost>>(FetchFailed(R.current.networkError))
          : Stale<List<MoodleForumPost>>(
              data, FetchFailed(R.current.networkError));
    }
    final result = await super.getDiscussionPosts(discussionId);
    // 測試是離線的，快取命中會回 Stale；這裡要的是「重抓成功」。
    final data = result.dataOrNull;
    return data == null ? result : Ok<List<MoodleForumPost>>(data);
  }
}
