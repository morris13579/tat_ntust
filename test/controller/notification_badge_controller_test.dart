import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/service/connectivity_probe.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeRepo extends MoodleRepository {
  int? next = 3;
  int calls = 0;

  @override
  Future<int?> fetchUnreadNotificationCount() async {
    calls++;
    return next;
  }
}

/// 課表頁大聲公上的未讀數。
void main() {
  late _FakeRepo repo;
  DateTime fakeNow = DateTime(2025, 9, 15, 12, 0);

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
    fakeNow = DateTime(2025, 9, 15, 12, 0);
    NotificationBadgeController.clock = () => fakeNow;
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AuthSession.instance = const UninstalledAuthSession();
    TaskUiDelegate.instance = const NoopTaskUiDelegate();
    ConnectivityProbe.instance = const PlatformConnectivityProbe();
    NotificationBadgeController.clock = DateTime.now;
  });

  NotificationBadgeController build() {
    final controller = NotificationBadgeController();
    addTearDown(controller.unread.close);
    return controller;
  }

  test('抓得到就更新未讀數', () async {
    final controller = build();

    await controller.refresh();

    expect(controller.unread.value, 3);
  });

  test('抓不到時保留上一個值：歸零等於謊稱「沒有新通知」', () async {
    final controller = build();
    await controller.refresh();

    repo.next = null;
    await controller.refresh(force: true);

    expect(controller.unread.value, 3);
  });

  test('一分鐘內不重打；過了節流時間才會再打', () async {
    final controller = build();
    await controller.refresh();

    fakeNow = fakeNow.add(const Duration(seconds: 30));
    await controller.refresh();
    expect(repo.calls, 1);

    fakeNow = fakeNow.add(const Duration(seconds: 31));
    await controller.refresh();
    expect(repo.calls, 2);
  });

  test('force 不受節流限制', () async {
    final controller = build();
    await controller.refresh();

    await controller.refresh(force: true);

    expect(repo.calls, 2);
  });

  test('登出歸零，而且下一次 refresh 不會被節流擋掉', () async {
    final controller = build();
    await controller.refresh();

    controller.reset();
    expect(controller.unread.value, 0);

    repo.next = 5;
    await controller.refresh();
    expect(repo.calls, 2);
    expect(controller.unread.value, 5);
  });

  test('負數夾成 0', () {
    final controller = build();

    controller.setCount(-1);

    expect(controller.unread.value, 0);
  });
}
