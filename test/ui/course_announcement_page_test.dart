import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/course_data/course_data_controller.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/ui/pages/course_data/screen/course_announcement_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_thread_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_discussion_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_forum_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 課程頁「公告」分頁的畫面規格。離線、快取預先塞好，與 course_assignment_page_test
/// 同一套。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const courseId = 'CS3001701';

  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    TaskUiDelegate.instance = RecordingUi();
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
    MoodleRepository.instance = MoodleRepository();
  });

  tearDown(() {
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  final courseInfo = CourseInfoJson(
    main:
        CourseMainInfoJson(course: CourseMainJson(id: courseId, name: '作業系統')),
  );

  Future<void> seed(MoodleModForumGetForumDiscussions data) =>
      CacheStore.instance.write(
        CacheKey<MoodleModForumGetForumDiscussions>(
          'cache_moodle_message',
          courseId,
          decode: (json) => MoodleModForumGetForumDiscussions.fromJson(json),
        ),
        data,
      );

  Future<void> seedDirectory(List<MoodleCoreCourseGetContents> contents) =>
      CacheStore.instance.write(
        CacheKey<List<MoodleCoreCourseGetContents>>(
          'cache_moodle_directory',
          courseId,
          decode: (json) => (json as List)
              .map((e) => MoodleCoreCourseGetContents.fromJson(e))
              .toList(),
        ),
        contents,
      );

  Future<void> seedForumDiscussions(int forumId, List<Discussions> list) =>
      CacheStore.instance.write(
        CacheKey<List<Discussions>>(
          'cache_moodle_forum_discussions',
          forumId.toString(),
          decode: (json) => (json as List)
              .map((e) => Discussions.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        ),
        list,
      );

  Future<CourseDataController> pump(WidgetTester tester,
      {bool withDirectory = false}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = CourseDataController(courseId);
    await controller.loadAnnouncements();
    if (withDirectory) await controller.loadDirectory();
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: CourseAnnouncementPage(
          courseInfo,
          controller: controller,
          errorBuilder: (m) => Text('ERR:$m'),
          openWebView: (title, url) async {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);
    return controller;
  }

  /// fixture 的兩則加一則自己捏的，用來驗「沒有回覆就沒有回覆數」。
  MoodleModForumGetForumDiscussions threeDiscussions() {
    final data = fixtureDiscussions();
    data.discussions.add(Discussions(
      id: 8803,
      discussion: 7703,
      name: '停課通知',
      subject: '停課通知',
      message: '<p>本週停課。</p>',
      userfullname: '李助教',
      created: 1755000000,
      modified: 1755000000,
    ));
    return data;
  }

  /// 一列上的第二行。`Text.rich` 拆成好幾個 span，所以比對的是整段純文字。
  String metaLineAt(WidgetTester tester, String title) {
    final card = find.ancestor(
        of: find.text(title), matching: find.byType(ForumDiscussionCard));
    final metas = tester.widgetList<Text>(
        find.descendant(of: card, matching: find.byType(Text)));
    return metas
        .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
        .firstWhere((s) => s.contains(' · '), orElse: () => '');
  }

  testWidgets('三則公告：置頂圖示、作者與日期，沒有回覆數也沒有已讀未讀', (tester) async {
    await seed(threeDiscussions());

    await pump(tester);

    // 伺服器 format_string 過的 `&amp;`，connector 已還原。
    expect(find.text('期中考 & 補考公告'), findsOneWidget);
    expect(find.textContaining('&amp;'), findsNothing);
    expect(find.text('第一週上課說明'), findsOneWidget);
    expect(find.text('停課通知'), findsOneWidget);

    expect(find.byIcon(LucideIcons.pin), findsOneWidget,
        reason: '只有第一則是 pinned');
    // 純公告頁沒有回覆數（設計稿 7e），也沒有紅點——App 不回寫 Moodle 的
    // 閱讀狀態。
    expect(find.byIcon(LucideIcons.messageCircle), findsNothing);
    expect(find.text('3 則回覆'), findsNothing);

    // fixture 那則是老師編輯過的（created < modified）。清單印建立時間，
    // 才會跟詳情頁第一篇印的是同一個時間。年月由分組標題說，列上只留日期。
    final created = DateTime.fromMillisecondsSinceEpoch(1756900000 * 1000);
    expect(metaLineAt(tester, '期中考 & 補考公告'),
        '王老師 · ${DateFormat.d().format(created)}');
    final edited = DateFormat.jm()
        .format(DateTime.fromMillisecondsSinceEpoch(1757000000 * 1000));
    expect(find.textContaining(edited), findsNothing);
  });

  testWidgets('分組標題只寫月份，不寫年份', (tester) async {
    await seed(threeDiscussions());

    await pump(tester);

    final month = DateFormat.MMM()
        .format(DateTime.fromMillisecondsSinceEpoch(1756900000 * 1000));
    expect(find.text(month), findsWidgets);
    final withYear = DateFormat.yMMM()
        .format(DateTime.fromMillisecondsSinceEpoch(1756900000 * 1000));
    expect(find.text(withYear), findsNothing);
  });

  testWidgets('userfullname 是「學號 @ 姓名」時，名字在前、學號自成一段', (tester) async {
    final data = MoodleModForumGetForumDiscussions(discussions: [
      Discussions(
        id: 8810,
        discussion: 7710,
        name: 'Project 4 環境配置',
        userfullname: 'B11000002 @ 溫冠華',
        created: 1755000000,
        modified: 1755000000,
      ),
    ]);
    await seed(data);

    await pump(tester);

    final created = DateTime.fromMillisecondsSinceEpoch(1755000000 * 1000);
    expect(metaLineAt(tester, 'Project 4 環境配置'),
        '溫冠華 · B11000002 · ${DateFormat.d().format(created)}');
  });

  testWidgets('當天發的才印時間——那是唯一一個「幾號」分不出先後的情況', (tester) async {
    final today = DateTime(2025, 6, 12, 10, 52);
    final yesterday = DateTime(2025, 6, 11, 9, 5);
    Discussions at(DateTime t, String name) => Discussions(
          id: t.millisecondsSinceEpoch ~/ 1000,
          discussion: t.millisecondsSinceEpoch ~/ 1000,
          name: name,
          userfullname: '王老師',
          created: t.millisecondsSinceEpoch ~/ 1000,
          modified: t.millisecondsSinceEpoch ~/ 1000,
        );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          ForumDiscussionCard(
              discussion: at(today, '今天的公告'), now: today, onTap: () {}),
          ForumDiscussionCard(
              discussion: at(yesterday, '昨天的公告'), now: today, onTap: () {}),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
        metaLineAt(tester, '今天的公告'), '王老師 · ${DateFormat.jm().format(today)}');
    expect(metaLineAt(tester, '昨天的公告'),
        '王老師 · ${DateFormat.d().format(yesterday)}');
  });

  /// 課程討論區（fixture 的 instance 5499）的兩則主題。
  List<Discussions> forumDiscussions() => [
        Discussions(
          id: 9001,
          discussion: 8001,
          name: '想請問為甚麼pipe line register 用 latch',
          userfullname: 'B11000005 @ 胡逸祥',
          created: 1756950000,
          modified: 1756950000,
          numreplies: 3,
        ),
        Discussions(
          id: 9002,
          discussion: 8002,
          name: 'Project 4 的檔案大小',
          userfullname: 'B11000003 @ 何聿陞',
          created: 1755950000,
          modified: 1755950000,
        ),
      ];

  testWidgets('有課程討論區：併成同一條時間軸，chip 的數字等於清單的列數', (tester) async {
    await seed(fixtureDiscussions());
    await seedDirectory(fixtureCourseContents());
    await seedForumDiscussions(5499, forumDiscussions());

    await pump(tester, withDirectory: true);

    // 公告與討論混排在同一份清單裡。
    expect(find.text('期中考 & 補考公告'), findsOneWidget);
    expect(find.text('想請問為甚麼pipe line register 用 latch'), findsOneWidget);
    expect(find.byType(ForumDiscussionCard), findsNWidgets(4));

    expect(find.text(R.current.forumFilterAll), findsOneWidget);
    expect(find.text('公告 2'), findsOneWidget);
    expect(find.text('討論 2'), findsOneWidget);

    // 討論串才有回覆數，公告沒有。
    expect(find.byIcon(LucideIcons.messageCircle), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('點「公告」chip 只留公告，數量與剩下的列數一致', (tester) async {
    await seed(fixtureDiscussions());
    await seedDirectory(fixtureCourseContents());
    await seedForumDiscussions(5499, forumDiscussions());

    await pump(tester, withDirectory: true);
    await tester.tap(find.text('公告 2'));
    await tester.pumpAndSettle();

    expect(find.byType(ForumDiscussionCard), findsNWidgets(2));
    expect(find.text('想請問為甚麼pipe line register 用 latch'), findsNothing);
    expect(find.text('期中考 & 補考公告'), findsOneWidget);
  });

  testWidgets('點進討論區那一列時帶的是它自己的 forum id，而且不是唯讀', (tester) async {
    await seed(fixtureDiscussions());
    await seedDirectory(fixtureCourseContents());
    await seedForumDiscussions(5499, forumDiscussions());

    await pump(tester, withDirectory: true);
    await tester.tap(find.text('想請問為甚麼pipe line register 用 latch'));
    await tester.pumpAndSettle();

    final page = tester
        .widget<CourseForumThreadPage>(find.byType(CourseForumThreadPage));
    expect(page.forumId, 5499);
    expect(page.discussionId, 8001);
    expect(page.readOnly, isFalse, reason: '課程討論區的主題學生回得了');
  });

  testWidgets('只有公佈欄的課：沒有 chip，就是純公告頁', (tester) async {
    await seed(fixtureDiscussions());
    await seedDirectory([
      MoodleCoreCourseGetContents(
        id: 4001,
        name: '一般',
        modules: [
          Modules(
            id: 91000,
            name: '課程公佈欄',
            instance: 5500,
            modname: 'forum',
            url: 'https://moodle2.ntust.edu.tw/mod/forum/view.php?id=91000',
          ),
        ],
      ),
    ]);

    await pump(tester, withDirectory: true);

    expect(find.byType(ForumDiscussionCard), findsNWidgets(2));
    expect(find.text(R.current.forumFilterAll), findsNothing);
  });

  testWidgets('沒有公告區：畫專屬空狀態，不畫清單也不彈任何對話框', (tester) async {
    await seed(MoodleModForumGetForumDiscussions(forumFound: false));

    await pump(tester);

    expect(find.text('這門課沒有公告區'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.textContaining('ERR:'), findsNothing);
    // 這次改動的重點：沒有公告區不是失敗，不該跳重試框。
    expect((TaskUiDelegate.instance as RecordingUi).confirmCalls, 0);
  });

  testWidgets('有公告區但沒有公告 → 暫無公告', (tester) async {
    await seed(MoodleModForumGetForumDiscussions());

    await pump(tester);

    expect(find.text('暫無公告'), findsOneWidget);
    expect(find.text('這門課沒有公告區'), findsNothing);
  });

  testWidgets('抓不到也沒有快取 → 注入的 errorBuilder', (tester) async {
    await pump(tester);

    expect(find.text('ERR:${R.current.networkError}'), findsOneWidget);
  });

  testWidgets('點一張卡 → 進討論串頁', (tester) async {
    await seed(threeDiscussions());

    await pump(tester);
    await tester.tap(find.text('期中考 & 補考公告'));
    await tester.pumpAndSettle();

    expect(find.byType(CourseForumThreadPage), findsOneWidget);
  });
}
