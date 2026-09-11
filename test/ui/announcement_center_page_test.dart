import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/announcement/announcement_center_controller.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/repository/app_notice_repository.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/components/html/moodle_html_view.dart';
import 'package:flutter_app/ui/components/page/empty_state.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:flutter_app/ui/pages/announcement/announcement_center_page.dart';
import 'package:flutter_app/ui/pages/announcement/announcement_page.dart';
import 'package:flutter_app/ui/pages/announcement/components/announcement_banner.dart';
import 'package:flutter_app/ui/pages/announcement/components/notification_empty_view.dart';
import 'package:flutter_app/ui/pages/announcement/components/notification_groups.dart';
import 'package:flutter_app/ui/pages/announcement/notification_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_notification_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeRepo extends MoodleRepository {
  MoodleNotificationList? nextList;
  bool markAllResult = true;

  @override
  Future<MoodleNotificationList?> fetchNotifications() async => nextList;

  @override
  Future<bool> writeNotificationRead(int notificationId) async => true;

  @override
  Future<bool> writeAllNotificationsRead() async => markAllResult;
}

class _FakeNoticeRepo extends AppNoticeRepository {
  List<AnnouncementInfoJson> next = [];

  @override
  Future<List<AnnouncementInfoJson>> fetchNotices() async => next;
}

/// 通知頁的畫面規格。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRepo repo;
  late _FakeNoticeRepo noticeRepo;
  late RecordingUi ui;

  setUpAll(() async {
    await loadTestL10n();
    // DateFormat.MMMd() 需要 zh_TW 的日期符號。
    await initializeDateFormatting();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    noticeRepo = _FakeNoticeRepo();
    ui = RecordingUi();
    MoodleRepository.instance = repo;
    AppNoticeRepository.instance = noticeRepo;
    AuthSession.instance = FakeAuthSession();
    TaskUiDelegate.instance = ui;
    ConnectivityProbe.instance = FakeConnectivityProbe();
    NotificationBadgeController.instance = NotificationBadgeController();
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AppNoticeRepository.instance = AppNoticeRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  final now = DateTime(2025, 9, 15, 12, 0);

  AnnouncementInfoJson notice(String title, DateTime start) =>
      AnnouncementInfoJson(
        title: title,
        content: '公告的 Markdown 內文',
        startTime: start,
        endTime: start.add(const Duration(days: 30)),
        test: false,
      );

  /// 先把 controller 載好再 pump：這一頁在收到注入的 controller 時不會自己
  /// 再發請求（同 course_assignment_page_test 的做法）。
  Future<AnnouncementCenterController> pump(
    WidgetTester tester, {
    bool load = true,
    List<(String, String)>? opened,
  }) async {
    final controller = AnnouncementCenterController();
    if (load) await controller.loadAll();
    await tester.pumpWidget(GetMaterialApp(
      home: AnnouncementCenterPage(
        controller: controller,
        clock: () => now,
        openWebView: (title, url) async => opened?.add((title, url)),
      ),
    ));
    if (load) {
      await tester.pumpAndSettle();
    } else {
      // 載入中的畫面有一個永不停的轉圈，pumpAndSettle 會逾時。
      await tester.pump();
    }
    // 先把畫面拆掉再關掉 Rx：Obx 還掛在上面時關掉來源會在 unmount 時炸。
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
    return controller;
  }

  testWidgets('載入中：標題已經在，通知那半在轉圈，公告卡還沒有東西可畫', (tester) async {
    await pump(tester, load: false);

    expect(find.text('通知'), findsOneWidget);
    // 公告只是一張卡，沒有自己的區塊標題，所以載入中不佔位。
    expect(find.byType(AnnouncementBanner), findsNothing);
    expect(find.byType(LoadingPage), findsOneWidget);
  });

  testWidgets('三則通知：標題、來源與時間、時間分組；伺服器語系的 timecreatedpretty 不出現',
      (tester) async {
    repo.nextList = fixtureNotifications();

    await pump(tester);

    expect(find.byType(NotificationTile), findsNWidgets(3));
    expect(find.text('作業已評分：HW1 & Report'), findsOneWidget);
    expect(find.textContaining('&amp;'), findsNothing);
    // 來源與時間分開排版：長活動名稱被 ellipsis 吃掉時，時間不會跟著消失。
    expect(find.text('HW1 & Report'), findsOneWidget);
    expect(find.textContaining(' · '), findsNWidgets(3));
    // timecreatedpretty 是伺服器端語系算好的，永遠不該被畫出來。
    expect(find.textContaining('hours ago'), findsNothing);
    expect(find.textContaining('day ago'), findsNothing);
    // 沒有 contexturlname 的 core 通知有自己的標籤。
    expect(find.text('系統通知'), findsOneWidget);
    // 分組標題就是設計稿上那三個灰色小標。哪一組會出現跟跑測試的時區有關
    // （fixture 是 epoch 秒），所以只確認用的是這三個而不是待辦清單那一套。
    expect(find.text('之後'), findsNothing);
    expect(find.text('逾期'), findsNothing);
    expect(
        ['今天', '本週', '更早']
            .where((l) => find.text(l).evaluate().isNotEmpty)
            .toList(),
        isNotEmpty);
  });

  testWidgets('未讀是圓點加半粗標題，已讀兩者都沒有', (tester) async {
    repo.nextList = fixtureNotifications();

    await pump(tester);

    expect(find.byKey(const ValueKey('unread-101')), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-102')), findsNothing);
    final unreadTitle = tester.widget<Text>(find.text('作業已評分：HW1 & Report'));
    expect(unreadTitle.style!.fontWeight, FontWeight.w500);
    final readTitle = tester.widget<Text>(find.text('作業系統: 期中考範圍公告'));
    expect(readTitle.style!.fontWeight, FontWeight.w400);
  });

  testWidgets('可開啟的一列是 chevron_right，就地展開的那一列是 chevron_down', (tester) async {
    repo.nextList = fixtureNotifications();

    await pump(tester);

    expect(find.byIcon(LucideIcons.chevronRight), findsNWidgets(2));
    expect(find.byIcon(LucideIcons.chevronDown), findsOneWidget);
  });

  testWidgets('點有 contexturl 的一列：開的是原始網址、圓點消失、未讀數減一', (tester) async {
    repo.nextList = fixtureNotifications();
    final opened = <(String, String)>[];

    await pump(tester, opened: opened);
    await tester.tap(find.text('作業已評分：HW1 & Report'));
    await tester.pumpAndSettle();

    expect(opened, [
      // 頁面不可以自己包 autologin：那是 RouteUtils.toWebViewPage 的事。
      (
        '作業已評分：HW1 & Report',
        'https://moodle2.ntust.edu.tw/mod/assign/view.php?id=77001'
      ),
    ]);
    expect(find.byKey(const ValueKey('unread-101')), findsNothing);
    expect(NotificationBadgeController.instance.unread.value, 1);
  });

  testWidgets('點沒有 contexturl 的一列：不開網頁，就地展開內文', (tester) async {
    repo.nextList = fixtureNotifications();
    final opened = <(String, String)>[];

    await pump(tester, opened: opened);
    expect(find.byType(MoodleHtmlView), findsNothing);
    await tester.tap(find.text('新的登入'));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(find.byType(MoodleHtmlView), findsOneWidget);
  });

  testWidgets('空清單 → 一張整頁的空狀態，第二行說明什麼東西會出現在這裡', (tester) async {
    repo.nextList = fixtureNotifications('popup_notifications_none');

    await pump(tester);

    expect(find.byType(NotificationEmptyView), findsOneWidget);
    expect(find.text('目前沒有通知'), findsOneWidget);
    expect(find.textContaining('作業截止與成績公布'), findsOneWidget);
    expect(find.byType(NotificationTile), findsNothing);
    // 整頁級的那張大圖是別的畫面在用的，這裡是自己那一份。
    expect(find.byType(EmptyState), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('清單空但有未讀數 → 第二行改成說是使用者在 Moodle 關掉了', (tester) async {
    repo.nextList = fixtureNotifications('popup_notifications_disabled');

    await pump(tester);

    expect(find.textContaining('你在 Moodle 關閉了站內通知'), findsOneWidget);
    expect(find.textContaining('一年只有兩三則'), findsNothing);
  });

  testWidgets('Moodle 那半失敗 → InlineErrorView，TAT 公告卡照樣畫得出來', (tester) async {
    noticeRepo.next = [notice('維護公告', DateTime.utc(2026, 9, 1))];
    repo.nextList = null;

    await pump(tester);

    expect(find.byType(InlineErrorView), findsOneWidget);
    expect(find.text('重新整理'), findsOneWidget);
    expect(find.byType(AnnouncementBanner), findsOneWidget);
    expect(find.text('維護公告'), findsOneWidget);
    expect(find.text('看完整公告'), findsOneWidget);
  });

  testWidgets('沒登入 Moodle → InlineErrorView 的按鈕是「登入」，而不是整頁錯誤畫面',
      (tester) async {
    AuthSession.instance = FakeAuthSession(
        ensureResults: [AuthFailure.notSignedIn], isSignedIn: false);

    await pump(tester);

    expect(find.byType(InlineErrorView), findsOneWidget);
    expect(find.text('登入'), findsOneWidget);
    expect(find.text('重新整理'), findsNothing);
  });

  testWidgets('Stale：橫幅出現，而且「全部標為已讀」不出現（那個寫入一定會失敗）', (tester) async {
    // 先成功一次寫進快取，再讓下一次失敗，得到真的 Stale。
    repo.nextList = fixtureNotifications();
    final warmUp = AnnouncementCenterController();
    await warmUp.loadNotifications();
    warmUp.dispose();
    repo.nextList = null;

    await pump(tester);

    expect(find.byType(NotificationTile), findsNWidgets(3));
    expect(find.byIcon(LucideIcons.history), findsOneWidget);
    expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
  });

  testWidgets('Stale 下點一則之後，橫幅還在、「全部標為已讀」仍然不出現', (tester) async {
    repo.nextList = fixtureNotifications();
    final warmUp = AnnouncementCenterController();
    await warmUp.loadNotifications();
    warmUp.dispose();
    repo.nextList = null;

    await pump(tester);
    await tester.tap(find.text('作業已評分：HW1 & Report'));
    await tester.pumpAndSettle();

    // 樂觀標記已讀不可以把 Stale 升級成 Ok：橫幅是使用者唯一知道自己在看
    // 舊資料的訊號，而那顆按鈕離線按下去一定失敗。
    expect(find.byIcon(LucideIcons.history), findsOneWidget);
    expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
  });

  testWidgets('全部標為已讀：確認後全部變已讀、未讀數歸零', (tester) async {
    repo.nextList = fixtureNotifications();

    await pump(tester);
    // 設計稿的清單裡沒有這顆鈕，所以它在 appbar 上，只有圖示與 tooltip。
    final button = find.byIcon(LucideIcons.checkCheck);
    expect(button, findsOneWidget);
    expect(
        tester
            .widget<IconButton>(
                find.ancestor(of: button, matching: find.byType(IconButton)))
            .tooltip,
        '全部標為已讀');

    await tester.tap(button);
    await tester.pumpAndSettle();
    // 伺服器預設在已讀 7 天後刪除通知，所以要先確認。對話框不寫數字：
    // 那支 WS 標的是 {notifications} 全部，比這一頁的未讀數多。
    expect(find.textContaining('含沒有顯示在這一頁的'), findsOneWidget);
    // 這是有破壞性的寫入，走共用的 TatDialog 並且主鈕是 destructive，
    // 不是隨手一個 AlertDialog。
    final dialog = tester.widget<TatDialog>(find.byType(TatDialog));
    expect(dialog.destructive, isTrue);
    expect(dialog.secondary?.label, '取消');
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unread-101')), findsNothing);
    expect(find.byKey(const ValueKey('unread-103')), findsNothing);
    expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
    expect(NotificationBadgeController.instance.unread.value, 0);
    expect(ui.toasts, ['已全部標為已讀']);
  });

  testWidgets('全部標為已讀失敗 → 圓點回來、toast 說失敗', (tester) async {
    repo.nextList = fixtureNotifications();
    repo.markAllResult = false;

    await pump(tester);
    await tester.tap(find.byIcon(LucideIcons.checkCheck));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unread-101')), findsOneWidget);
    expect(ui.toasts, ['標記全部已讀失敗']);
  });

  testWidgets('TAT 公告：只畫最新的一則、有未讀點，而且日期沒有被 toLocal 位移', (tester) async {
    // RemoteConfigUtils 把公告時間重建成 UTC 欄位裝台北的牆上時間，
    // toLocal() 會讓這一則變成 9/5。
    noticeRepo.next = [
      notice('新版上線', DateTime.utc(2026, 9, 6, 1, 0)),
      notice('舊公告', DateTime.utc(2020, 1, 1)),
    ];
    repo.nextList = fixtureNotifications('popup_notifications_none');

    final controller = await pump(tester);

    // 一年只有兩三則，開一個永遠只有 0–1 列的區塊比不開更空：卡片只畫最新的。
    expect(find.byType(AnnouncementBanner), findsOneWidget);
    expect(find.text('新版上線'), findsOneWidget);
    expect(find.text('舊公告'), findsNothing);
    expect(find.text('9月6日'), findsOneWidget);
    expect(find.text('9月5日'), findsNothing);
    // 進頁前沒讀過的那一則有未讀點。
    expect(find.byKey(const ValueKey('notice-unread')), findsOneWidget);
    expect(controller.lastReadSnapshot, DateTime.utc(2000));
  });

  testWidgets('點公告卡 → 進公告全文頁，兩則都翻得到', (tester) async {
    noticeRepo.next = [
      notice('新版上線', DateTime.utc(2026, 9, 6, 1, 0)),
      notice('舊公告', DateTime.utc(2020, 1, 1)),
    ];
    repo.nextList = fixtureNotifications('popup_notifications_none');

    await pump(tester);
    await tester.tap(find.text('看完整公告'));
    await tester.pumpAndSettle();

    expect(find.byType(AnnouncementPage), findsOneWidget);
    // 卡片上那一則就是第一頁，翻頁的控制項都在底部那一列。
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.text('下一則'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('舊公告'), findsOneWidget);
    // 最後一則才輪到「確定」。使用者自己點進來的沒有倒數。
    expect(find.text('確定'), findsOneWidget);
  });

  testWidgets('沒有 TAT 公告 → 不畫卡片，通知清單直接從第一個分組開始', (tester) async {
    noticeRepo.next = [];
    repo.nextList = fixtureNotifications();

    await pump(tester);

    expect(find.byType(AnnouncementBanner), findsNothing);
    expect(find.text('看完整公告'), findsNothing);
    expect(find.byType(NotificationTile), findsNWidgets(3));
  });

  test('icon 由 component 與 eventtype 決定，不抓伺服器的 iconurl', () {
    // iconurl 是站台主題圖：每一列要多一次網路請求，深色模式也不會反相。
    expect(NotificationTile.iconFor('mod_assign'), LucideIcons.clipboardList);
    expect(NotificationTile.iconFor('mod_forum'), LucideIcons.messagesSquare);
    expect(NotificationTile.iconFor('mod_quiz'), LucideIcons.fileQuestion);
    expect(NotificationTile.iconFor('mod_choice'), LucideIcons.vote);
    // 沒對到的模組仍然看得出是模組，core 與 null 才退回大聲公。
    expect(NotificationTile.iconFor('mod_wiki'), LucideIcons.puzzle);
    expect(NotificationTile.iconFor('moodle'), LucideIcons.bell);
    expect(NotificationTile.iconFor(null), LucideIcons.bell);
    // 成績通知是 core 的元件加上 grade 開頭的 eventtype，光看 component
    // 會落到大聲公；設計稿把成績另外畫成學士帽。
    expect(NotificationTile.iconFor('moodle', eventtype: 'gradenotification'),
        LucideIcons.graduationCap);
    expect(NotificationTile.iconFor('gradereport_user'),
        LucideIcons.graduationCap);
  });

  group('分組與時間欄', () {
    MoodleNotification at(DateTime created) =>
        MoodleNotification(timecreated: created.millisecondsSinceEpoch ~/ 1000);

    // 2025/9/17 是星期三，所以這一週從 9/15（一）起算。
    final wednesday = DateTime(2025, 9, 17, 12, 0);

    test('今天／本週／更早，本週從星期一起算', () {
      final today = at(DateTime(2025, 9, 17, 0, 5));
      final monday = at(DateTime(2025, 9, 15, 23, 59));
      final sunday = at(DateTime(2025, 9, 14, 23, 59));

      final groups =
          NotificationGroups.groupByAge([today, monday, sunday], wednesday);

      expect(groups.map((g) => g.bucket), [
        NotificationBucket.today,
        NotificationBucket.thisWeek,
        NotificationBucket.earlier,
      ]);
      expect(groups.first.items, [today]);
      expect(groups.last.items, [sunday]);
    });

    test('空的分組不會留下一個只有標題的區塊', () {
      final groups = NotificationGroups.groupByAge(
          [at(DateTime(2025, 9, 17, 8, 0))], wednesday);

      expect(groups, hasLength(1));
      expect(groups.single.bucket, NotificationBucket.today);
    });

    test('同一天只給時間，其餘給日期，跨年補年份', () {
      expect(
          NotificationGroups.formatCreatedTime(
              DateTime(2025, 9, 17, 14, 20), wednesday),
          '14:20');
      expect(
          NotificationGroups.formatCreatedTime(
              DateTime(2025, 9, 4, 9, 5), wednesday),
          '9月4日');
      expect(
          NotificationGroups.formatCreatedTime(
              DateTime(2024, 12, 31, 9, 5), wednesday),
          contains('2024'));
    });
  });

  test('公告卡的摘要是純文字：Markdown 的記號與網址都不佔那三行', () {
    expect(
      AnnouncementBanner.plainExcerpt(
          '## 標題\n\n- **分享課表**：產生 [QR](https://example.com) 讓同學掃。'),
      '標題 分享課表：產生 QR 讓同學掃。',
    );
  });

  test('這一頁不可以 import route_utils / error_page / base_page', () {
    // deps.py 的 MAX_SCC 棘輪擋得住，但那個數字看不出是誰違規；
    // 這條測試會直接指名檔案。
    for (final path in [
      'lib/ui/pages/announcement/announcement_center_page.dart',
      'lib/ui/pages/announcement/announcement_page.dart',
      'lib/ui/pages/announcement/notification_tile.dart',
      'lib/ui/pages/announcement/components/announcement_banner.dart',
      'lib/ui/pages/announcement/components/notification_empty_view.dart',
      'lib/ui/pages/announcement/components/notification_groups.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final forbidden in [
        'ui/routes/route_utils.dart',
        'ui/components/page/error_page.dart',
        'ui/components/page/base_page.dart',
      ]) {
        expect(source.contains(forbidden), isFalse,
            reason: '$path 不該 import $forbidden');
      }
    }
  });
}
