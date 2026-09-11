import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/ui/components/page/empty_state.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_thread_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/forum_discussion_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_forum_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 一般討論區清單頁的畫面規格。清單以快取 seed，離線所以不碰網路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    TaskUiDelegate.instance = RecordingUi();
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  final courseInfo = CourseInfoJson(
    main: CourseMainInfoJson(
        course: CourseMainJson(id: 'CS3001701', name: '作業系統')),
  );

  Future<void> seedDiscussions(int forumId, List<Discussions> list) =>
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

  Future<void> pump(WidgetTester tester,
      {List<(String, String)>? opened}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(GetMaterialApp(
      home: CourseForumPage(
        courseInfo,
        forumId: 5499,
        forumName: '課程討論區',
        forumUrl: 'https://moodle2.ntust.edu.tw/mod/forum/view.php?id=90999',
        errorBuilder: (message) => Text('ERROR:$message'),
        openWebView: (title, url) async => opened?.add((title, url)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('清單從快取畫出來（離線）', (tester) async {
    await seedDiscussions(5499, fixtureDiscussions().discussions);

    await pump(tester);

    expect(find.byType(ForumDiscussionCard), findsNWidgets(2));
    expect(find.text('期中考 & 補考公告'), findsOneWidget);
  });

  testWidgets('點一列會推進討論串頁，帶的是 discussion 不是 id', (tester) async {
    await seedDiscussions(5499, fixtureDiscussions().discussions);

    await pump(tester);
    await tester.tap(find.byType(ForumDiscussionCard).first);
    await tester.pumpAndSettle();

    final page = tester
        .widget<CourseForumThreadPage>(find.byType(CourseForumThreadPage));
    expect(page.discussionId, 7701);
    expect(page.title, '期中考 & 補考公告');
  });

  testWidgets('空清單畫空狀態', (tester) async {
    await seedDiscussions(5499, const []);

    await pump(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text(R.current.forumEmpty), findsOneWidget);
  });

  testWidgets('主題清單那一列有附件時畫迴紋針——App 現在做得出附件，清單就該看得出誰有', (tester) async {
    final list = fixtureDiscussions().discussions;
    await seedDiscussions(5499, list);

    await pump(tester);

    // fixture 的第一則帶附件，第二則沒有。
    expect(list.first.attachment, isTrue);
    expect(
      find.descendant(
          of: find.byType(ForumDiscussionCard),
          matching: find.byIcon(LucideIcons.paperclip)),
      findsOneWidget,
    );
  });

  testWidgets('AppBar 的「在網頁開啟」用注入的開啟器，網址帶語系', (tester) async {
    final opened = <(String, String)>[];
    await seedDiscussions(5499, fixtureDiscussions().discussions);

    await pump(tester, opened: opened);
    await tester.tap(find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(LucideIcons.externalLink)));
    await tester.pumpAndSettle();

    expect(opened.single.$1, '課程討論區');
    expect(opened.single.$2, contains('/mod/forum/view.php?id=90999'));
    expect(opened.single.$2, contains('lang='));
  });
}
