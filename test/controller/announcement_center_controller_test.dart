import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/announcement/announcement_center_controller.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/repository/app_notice_repository.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_notification_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeRepo extends MoodleRepository {
  MoodleNotificationList? nextList;
  bool markOneResult = true;
  bool markAllResult = true;
  int markOneCalls = 0;

  @override
  Future<MoodleNotificationList?> fetchNotifications() async => nextList;

  @override
  Future<bool> writeNotificationRead(int notificationId) async {
    markOneCalls++;
    return markOneResult;
  }

  @override
  Future<bool> writeAllNotificationsRead() async => markAllResult;
}

/// Remote Config 的 `_remoteConfig` 是 `late static`，測試不能碰真的那一支。
class _FakeNoticeRepo extends AppNoticeRepository {
  List<AnnouncementInfoJson>? next;

  @override
  Future<List<AnnouncementInfoJson>> fetchNotices() async =>
      next ?? (throw Exception('remote config 掛了'));
}

AnnouncementInfoJson notice(String title, DateTime start) =>
    AnnouncementInfoJson(
      title: title,
      content: 'content of $title',
      startTime: start,
      endTime: start.add(const Duration(days: 30)),
      test: false,
    );

void main() {
  late _FakeRepo repo;
  late _FakeNoticeRepo noticeRepo;
  late RecordingUi ui;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
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

  AnnouncementCenterController build() {
    final controller = AnnouncementCenterController();
    addTearDown(controller.dispose);
    return controller;
  }

  test('loadAll 兩半並行，一半失敗不影響另一半', () async {
    noticeRepo.next = [notice('維護公告', DateTime.utc(2026, 9, 1))];
    repo.nextList = null;
    final controller = build();

    await controller.loadAll();

    expect(controller.appNotices.value, isA<Ok<List<AnnouncementInfoJson>>>());
    expect(
        controller.notifications.value, isA<Failed<MoodleNotificationList>>());
  });

  test('載到清單就把未讀數推到紅點（不必再打一支 WS）', () async {
    repo.nextList = fixtureNotifications();
    final controller = build();

    await controller.loadNotifications();

    expect(NotificationBadgeController.instance.unread.value, 2);
  });

  test('markRead：樂觀更新會換一個新的 Ok 實例，未讀數減一', () async {
    repo.nextList = fixtureNotifications();
    final controller = build();
    await controller.loadNotifications();
    final before = controller.notifications.value;
    final target = controller.notifications.value!.dataOrNull!.notifications
        .firstWhere((n) => n.id == 101);

    await controller.markRead(target);

    // Ok 沒有覆寫 ==，所以 Obx 收得到的唯一訊號就是「不是同一顆」。
    expect(identical(controller.notifications.value, before), isFalse);
    expect(target.read, isTrue);
    expect(target.timeread, isNotNull);
    expect(controller.notifications.value!.dataOrNull!.unreadcount, 1);
    expect(NotificationBadgeController.instance.unread.value, 1);
    expect(ui.toasts, isEmpty);
  });

  test('markRead 失敗會回捲並 toast，頁面不會變成錯誤畫面', () async {
    repo.nextList = fixtureNotifications();
    repo.markOneResult = false;
    final controller = build();
    await controller.loadNotifications();
    final target = controller.notifications.value!.dataOrNull!.notifications
        .firstWhere((n) => n.id == 101);

    await controller.markRead(target);

    expect(target.read, isFalse);
    expect(target.timeread, isNull);
    expect(controller.notifications.value!.dataOrNull!.unreadcount, 2);
    expect(NotificationBadgeController.instance.unread.value, 2);
    expect(ui.toasts, ['標記已讀失敗']);
    expect(controller.notifications.value!.hasData, isTrue);
  });

  test('已讀的通知再點一次不打 WS', () async {
    repo.nextList = fixtureNotifications();
    final controller = build();
    await controller.loadNotifications();
    final alreadyRead = controller
        .notifications.value!.dataOrNull!.notifications
        .firstWhere((n) => n.id == 102);

    await controller.markRead(alreadyRead);

    expect(repo.markOneCalls, 0);
  });

  /// 先成功抓一次寫進快取，再讓下一次失敗，得到一個真的 Stale。
  Future<AnnouncementCenterController> staleController() async {
    repo.nextList = fixtureNotifications();
    final controller = build();
    await controller.loadNotifications();
    repo.nextList = null;
    await controller.loadNotifications();
    expect(
        controller.notifications.value, isA<Stale<MoodleNotificationList>>());
    return controller;
  }

  test('Stale 狀態下仍然可以標記已讀，但外殼型別要維持 Stale', () async {
    final controller = await staleController();
    final target = controller.notifications.value!.dataOrNull!.notifications
        .firstWhere((n) => n.id == 101);

    await controller.markRead(target);

    expect(target.read, isTrue);
    expect(repo.markOneCalls, 1);
    // 換成 Ok 會讓「你在看舊資料」的橫幅消失，還會把刻意藏起來的
    // 「全部標為已讀」變出來。
    expect(
        controller.notifications.value, isA<Stale<MoodleNotificationList>>());
  });

  test('Stale 不推紅點：快取裡的舊數字會蓋掉剛輪詢到的正確值', () async {
    // 快取裡是 unreadcount = 2 的那份，之後輪詢拿到伺服器確認過的 7。
    repo.nextList = fixtureNotifications();
    await build().loadNotifications();
    repo.nextList = null;
    NotificationBadgeController.instance.setCount(7);

    final controller = build();
    await controller.loadNotifications();

    expect(
        controller.notifications.value, isA<Stale<MoodleNotificationList>>());
    expect(NotificationBadgeController.instance.unread.value, 7);
  });

  test('清單空但未讀數不是 0（使用者關掉了站內通知）→ 紅點歸零並停掉輪詢', () async {
    repo.nextList = fixtureNotifications('popup_notifications_disabled');
    final controller = build();

    await controller.loadNotifications();

    // 清單永遠拿不到的未讀數，不該變成一顆使用者按不掉的紅點。
    expect(NotificationBadgeController.instance.unread.value, 0);
    await NotificationBadgeController.instance.refresh(force: true);
    expect(NotificationBadgeController.instance.unread.value, 0);
  });

  test('標記已讀成功會回寫快取：離線再開不會整批復活', () async {
    repo.nextList = fixtureNotifications();
    final controller = build();
    await controller.loadNotifications();
    final target = controller.notifications.value!.dataOrNull!.notifications
        .firstWhere((n) => n.id == 101);

    await controller.markRead(target);

    final cached =
        await CacheStore.instance.read(MoodleRepository.notificationsKey());
    expect(cached!.notifications.firstWhere((n) => n.id == 101).read, isTrue);
    expect(cached.unreadcount, 1);
  });

  test('markAllRead 成功也會回寫快取', () async {
    repo.nextList = fixtureNotifications();
    final controller = build();
    await controller.loadNotifications();

    await controller.markAllRead();

    final cached =
        await CacheStore.instance.read(MoodleRepository.notificationsKey());
    expect(cached!.notifications.every((n) => n.read), isTrue);
    expect(cached.unreadcount, 0);
  });

  test('markAllRead 成功 → 全部已讀、未讀數與紅點歸零', () async {
    repo.nextList = fixtureNotifications();
    final controller = build();
    await controller.loadNotifications();

    expect(await controller.markAllRead(), isTrue);

    final data = controller.notifications.value!.dataOrNull!;
    expect(data.notifications.every((n) => n.read), isTrue);
    expect(data.unreadcount, 0);
    expect(NotificationBadgeController.instance.unread.value, 0);
    expect(controller.markingAll.value, isFalse);
  });

  test('markAllRead 失敗 → toast，資料不動', () async {
    repo.nextList = fixtureNotifications();
    repo.markAllResult = false;
    final controller = build();
    await controller.loadNotifications();

    expect(await controller.markAllRead(), isFalse);

    final data = controller.notifications.value!.dataOrNull!;
    expect(data.unreadcount, 2);
    expect(data.notifications.first.read, isFalse);
    expect(ui.toasts, ['標記全部已讀失敗']);
  });

  test('refreshAll 不會把狀態設回 null（畫面不該閃一次載入中）', () async {
    noticeRepo.next = [notice('維護公告', DateTime.utc(2026, 9, 1))];
    repo.nextList = fixtureNotifications();
    final controller = build();
    await controller.loadAll();

    final seen = <Result<MoodleNotificationList>?>[];
    controller.notifications.listen(seen.add);
    await controller.refreshAll();

    expect(seen, isNotEmpty);
    expect(seen.contains(null), isFalse);
  });

  test('看過這一頁就等於公告已讀，但畫面上的未讀點用進頁前的快照算', () async {
    final published = DateTime.utc(2026, 9, 1);
    noticeRepo.next = [notice('維護公告', published)];
    final controller = build();

    await controller.loadAppNotices();

    // 快照停在寫入之前，所以這一次進頁仍然看得到未讀點。
    expect(
        AnnouncementCenterController.isUnread(
            noticeRepo.next!.single, controller.lastReadSnapshot),
        isTrue);
    // 已讀時間確實寫下去了：下一次進頁（與啟動彈窗）就不會再算成未讀。
    final lastRead = await SettingsStore.instance.announcementLastRead;
    expect(lastRead.isAfter(published), isTrue);
    expect(
        AnnouncementCenterController.isUnread(
            noticeRepo.next!.single, lastRead),
        isFalse);
  });

  test('下拉重新整理不會讓未讀點消失（快照只取一次）', () async {
    final published = DateTime.utc(2026, 9, 1);
    noticeRepo.next = [notice('維護公告', published)];
    final controller = build();
    await controller.loadAppNotices();
    final snapshot = controller.lastReadSnapshot;

    await controller.refreshAll();

    // 重新讀一次已讀時間會拿到剛剛自己寫下去的那一刻，未讀點就沒了。
    expect(controller.lastReadSnapshot, snapshot);
    expect(
        AnnouncementCenterController.isUnread(
            noticeRepo.next!.single, controller.lastReadSnapshot),
        isTrue);
  });

  test('Stale（離線讀快取）不寫已讀時間：那批公告可能是幾個月前的', () async {
    final published = DateTime.utc(2026, 9, 1);
    noticeRepo.next = [notice('維護公告', published)];
    final warmUp = build();
    await warmUp.loadAppNotices();
    // 把已讀時間洗回去，讓下一次的寫入看得出來。
    await SettingsStore.instance.markAnnouncementReadUpTo(DateTime.utc(2000));
    noticeRepo.next = null;

    final controller = build();
    await controller.loadAppNotices();

    expect(
        controller.appNotices.value, isA<Stale<List<AnnouncementInfoJson>>>());
    expect(
        await SettingsStore.instance.announcementLastRead, DateTime.utc(2000));
  });

  test('已讀時間寫的是畫面上最新那一則的發布時間，不是 now', () async {
    final published = DateTime.utc(2026, 9, 1, 10);
    noticeRepo.next = [
      notice('維護公告', published),
      notice('舊公告', DateTime.utc(2026, 1, 1)),
    ];
    final controller = build();

    await controller.loadAppNotices();

    // 寫 now 會把「Remote Config 還沒抓到、但已經發布」的公告一起吃掉。
    final lastRead = await SettingsStore.instance.announcementLastRead;
    expect(lastRead, published.add(const Duration(milliseconds: 1)));
  });

  test('已讀時間不會倒退：啟動彈窗按過確定之後不該被這一頁洗回去', () async {
    final confirmed = DateTime.utc(2026, 12, 1);
    await SettingsStore.instance.markAnnouncementReadUpTo(confirmed);
    noticeRepo.next = [notice('舊公告', DateTime.utc(2026, 1, 1))];
    final controller = build();

    await controller.loadAppNotices();

    expect(await SettingsStore.instance.announcementLastRead, confirmed);
  });

  test('公告清單是空的就不寫已讀時間', () async {
    noticeRepo.next = [];
    final controller = build();

    await controller.loadAppNotices();

    expect(
        await SettingsStore.instance.announcementLastRead, DateTime.utc(2000));
  });

  test('sortForList 新的排前面', () {
    final list = [
      notice('舊', DateTime.utc(2026, 1, 1)),
      notice('新', DateTime.utc(2026, 9, 1)),
      notice('中', DateTime.utc(2026, 5, 1)),
    ];

    expect(AnnouncementCenterController.sortForList(list).map((e) => e.title),
        ['新', '中', '舊']);
  });
}
