import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/moodle_notification_fixtures.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 不打網路的 [MoodleRepository]：只換掉「真的去問 Moodle」那四步。
class _FakeRepo extends MoodleRepository {
  MoodleNotificationList? nextList;
  int? nextCount;
  bool markOneResult = true;
  bool markAllResult = true;
  int listCalls = 0;

  @override
  Future<MoodleNotificationList?> fetchNotifications() async {
    listCalls++;
    return nextList;
  }

  @override
  Future<int?> fetchUnreadNotificationCount() async => nextCount;

  @override
  Future<bool> writeNotificationRead(int notificationId) async => markOneResult;

  @override
  Future<bool> writeAllNotificationsRead() async => markAllResult;
}

/// 站內通知四個 repository 方法的三態行為。
void main() {
  late _FakeRepo repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestL10n();
  });

  setUp(() {
    resetAppStatics();
    repo = _FakeRepo();
    MoodleRepository.instance = repo;
    AuthSession.instance = FakeAuthSession();
    TaskUiDelegate.instance = RecordingUi();
    ConnectivityProbe.instance = FakeConnectivityProbe();
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
  });

  Future<MoodleNotificationList?> cached() =>
      CacheStore.instance.read(MoodleRepository.notificationsKey());

  test('抓到就回 Ok，並寫進快取', () async {
    repo.nextList = fixtureNotifications();

    final result = await MoodleRepository.instance.getNotifications();

    expect(result, isA<Ok<MoodleNotificationList>>());
    expect(result.dataOrNull!.notifications.map((n) => n.id), [101, 102, 103]);
    // 快取存的是 connector 還原過的字串。
    expect((await cached())!.notifications.first.subject, '作業已評分：HW1 & Report');
  });

  test('清單空但 unreadcount 不是 0 也是 Ok（不能被當成失敗）', () async {
    repo.nextList = fixtureNotifications('popup_notifications_disabled');

    final result = await MoodleRepository.instance.getNotifications();

    expect(result, isA<Ok<MoodleNotificationList>>());
    expect(result.dataOrNull!.unreadcount, 4);
  });

  test('抓不到但快取有 → Stale；快取沒有 → Failed', () async {
    await CacheStore.instance
        .write(MoodleRepository.notificationsKey(), fixtureNotifications());
    repo.nextList = null;

    final stale =
        await MoodleRepository.instance.getNotifications(background: true);
    expect(stale, isA<Stale<MoodleNotificationList>>());
    expect(stale.dataOrNull!.notifications.length, 3);

    await CacheStore.instance.clearAll();
    final failed =
        await MoodleRepository.instance.getNotifications(background: true);
    expect(failed, isA<Failed<MoodleNotificationList>>());
  });

  test('離線時直接讀快取，連問都不問', () async {
    await CacheStore.instance
        .write(MoodleRepository.notificationsKey(), fixtureNotifications());
    ConnectivityProbe.instance = FakeConnectivityProbe(online: false);

    final result =
        await MoodleRepository.instance.getNotifications(background: true);

    expect(result, isA<Stale<MoodleNotificationList>>());
    expect((result as Stale).reason, isA<Offline>());
    expect(repo.listCalls, 0);
  });

  test('未讀數 0 是 Ok，不是失敗；抓不到才是 Failed', () async {
    repo.nextCount = 0;
    expect(await MoodleRepository.instance.getUnreadNotificationCount(),
        isA<Ok<int>>());

    repo.nextCount = null;
    expect(await MoodleRepository.instance.getUnreadNotificationCount(),
        isA<Failed<int>>());
  });

  test('connector 回 false 的寫入必須是 Failed，不能被當成成功', () async {
    repo.markOneResult = false;
    repo.markAllResult = false;

    expect(await MoodleRepository.instance.markNotificationRead(101),
        isA<Failed<bool>>());
    expect(await MoodleRepository.instance.markAllNotificationsRead(),
        isA<Failed<bool>>());

    repo.markOneResult = true;
    repo.markAllResult = true;
    expect(await MoodleRepository.instance.markNotificationRead(101),
        isA<Ok<bool>>());
    expect(await MoodleRepository.instance.markAllNotificationsRead(),
        isA<Ok<bool>>());
  });

  test('寫入是背景模式：不彈重試框、不開登入頁', () async {
    final ui = RecordingUi();
    TaskUiDelegate.instance = ui;
    final auth = FakeAuthSession();
    AuthSession.instance = auth;
    repo.markOneResult = false;

    await MoodleRepository.instance.markNotificationRead(101);

    expect(ui.confirmCalls, 0);
    expect(auth.ensureInteractive, everyElement(isFalse));
  });
}
