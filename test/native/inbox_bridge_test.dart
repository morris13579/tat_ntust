import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/controller/announcement/notification_badge_controller.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/native/inbox_bridge.dart';
import 'package:flutter_app/src/repository/app_notice_repository.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/recording_ui.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeNotices extends AppNoticeRepository {
  Result<List<AnnouncementInfoJson>> next = const Ok([]);

  @override
  Future<Result<List<AnnouncementInfoJson>>> getNotices() async => next;
}

class _FakeMoodle extends MoodleRepository {
  Result<MoodleNotificationList> list = Ok(MoodleNotificationList());
  final List<bool> backgrounds = [];
  Result<bool> markResult = const Ok(true);

  @override
  Future<Result<MoodleNotificationList>> getNotifications(
      {bool background = false}) async {
    backgrounds.add(background);
    return list;
  }

  @override
  Future<Result<bool>> markNotificationRead(int notificationId) async =>
      markResult;

  @override
  Future<Result<bool>> markAllNotificationsRead() async => const Ok(true);

  @override
  Future<void> saveNotifications(MoodleNotificationList list) async {}

  @override
  Future<Result<int>> getUnreadNotificationCount() async => const Ok(7);
}

final _now = DateTime(2025, 9, 5, 15, 30);
const _host = 'https://moodle2.ntust.edu.tw';

MoodleNotification notification(
  int id,
  DateTime created, {
  String? url,
  String? source,
  String? component,
  String? eventtype,
  bool read = false,
}) =>
    MoodleNotification(
      id: id,
      subject: '通知 $id',
      fullmessagehtml: '<p>內文 $id</p>',
      contexturl: url,
      contexturlname: source,
      timecreated: created.millisecondsSinceEpoch ~/ 1000,
      read: read,
      component: component,
      eventtype: eventtype,
    );

AnnouncementInfoJson notice(String title, DateTime start) =>
    AnnouncementInfoJson(
      title: title,
      content: '**$title** 的內容',
      startTime: start,
      endTime: start.add(const Duration(days: 30)),
      test: false,
    );

/// 原生版的通知中心。分組、哪一列點了開網頁、已讀改不改得回來、紅點——都是 Dart 的判斷，
/// 壞了原生版會把外站網址帶著鑰匙開，或讓按不掉的紅點一直亮著。
void main() {
  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  late _FakeMoodle moodle;
  late _FakeNotices notices;
  late RecordingUi ui;
  late InboxBridge bridge;

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    moodle = _FakeMoodle();
    MoodleRepository.instance = moodle;
    notices = _FakeNotices();
    AppNoticeRepository.instance = notices;
    ui = RecordingUi();
    TaskUiDelegate.instance = ui;
    NotificationBadgeController.instance = NotificationBadgeController();
    bridge = InboxBridge(clock: () => _now);
  });

  tearDown(() {
    MoodleRepository.instance = MoodleRepository();
    AppNoticeRepository.instance = AppNoticeRepository();
  });

  group('通知', () {
    test('依今天／本週／更早分組；只有自家網址可以開；進頁不開登入頁', () async {
      moodle.list = Ok(MoodleNotificationList(unreadcount: 1, notifications: [
        notification(1, DateTime(2025, 9, 5, 14, 20),
            url: '$_host/mod/assign/view.php?id=77',
            source: '計算機組織',
            component: 'mod_assign'),
        notification(2, DateTime(2025, 9, 3, 10),
            component: 'mod_forum', read: true),
        notification(3, DateTime(2025, 8, 20, 9),
            url: 'https://docs.google.com/forms/x',
            component: 'moodle',
            eventtype: 'gradenotification',
            read: true),
      ]));

      final state = await bridge.load();

      expect(state.sections.map((s) => s.title), ['今天', '本週', '更早']);
      final rows = state.sections.expand((s) => s.rows).toList();
      expect(rows.map((r) => r.kind),
          [InboxKind.assign, InboxKind.forum, InboxKind.grade]);
      expect(rows.map((r) => r.openable), [true, false, false]);
      expect(rows.map((r) => r.unread), [true, false, false]);
      expect(rows[0].source, '計算機組織');
      expect(rows[1].source, '系統通知');
      expect(rows[1].bodyHtml, '<p>內文 2</p>');
      expect(state.canMarkAll, isTrue);
      expect(moodle.backgrounds, [true]);
    });

    test('清單空但未讀數不是 0：說明換成在 Moodle 關掉了站內通知', () async {
      moodle.list = Ok(MoodleNotificationList(unreadcount: 3));

      final state = await bridge.load();

      expect(state.sections, isEmpty);
      expect(state.emptyMessage, '目前沒有通知');
      expect(state.emptyHint, contains('Moodle'));
    });

    test('離線讀到的舊資料：帶著原因，不給全部標為已讀', () async {
      moodle.list = Stale(
          MoodleNotificationList(unreadcount: 1, notifications: [
            notification(1, DateTime(2025, 9, 5, 9)),
          ]),
          const FetchFailed('離線'));

      final state = await bridge.load();

      expect(state.notice, '離線');
      expect(state.canMarkAll, isFalse);
    });

    test('標已讀：成功就改掉圓點並推紅點；失敗改回來並提示', () async {
      moodle.list = Ok(MoodleNotificationList(unreadcount: 2, notifications: [
        notification(1, DateTime(2025, 9, 5, 9)),
        notification(2, DateTime(2025, 9, 5, 8)),
      ]));
      await bridge.load();

      final read = await bridge.markRead(1);
      expect(read.sections.first.rows.first.unread, isFalse);
      expect(NotificationBadgeController.instance.unread.value, 1);

      moodle.markResult = const Failed(FetchFailed());
      final failed = await bridge.markRead(2);
      expect(failed.sections.first.rows[1].unread, isTrue);
      expect(ui.toasts, ['標記已讀失敗']);
    });

    test('全部標為已讀', () async {
      moodle.list = Ok(MoodleNotificationList(unreadcount: 1, notifications: [
        notification(1, DateTime(2025, 9, 5, 9)),
      ]));
      await bridge.load();

      final result = await bridge.markAllRead();

      expect(result.ok, isTrue);
      expect(result.state.sections.first.rows.single.unread, isFalse);
      expect(result.state.canMarkAll, isFalse);
    });

    test('鈴鐺上的未讀數', () async {
      expect(await bridge.badge(true), 7);
    });
  });

  group('TAT 公告', () {
    test('新的排前面；進頁前沒讀過的有未讀點，看過一次之後就沒有', () async {
      notices.next = Ok([
        notice('舊的', DateTime.utc(2025, 8, 1, 9)),
        notice('新的', DateTime.utc(2025, 9, 1, 9)),
      ]);

      final first = await bridge.load();
      final second = await bridge.load();

      expect(first.notices.map((n) => n.title), ['新的', '舊的']);
      expect(first.notices.first.excerpt, '新的 的內容');
      expect(first.noticeUnread, isTrue);
      expect(second.noticeUnread, isFalse);
    });
  });

  group('預覽', () {
    test('假資料不打網路；開啟只提示網址', () async {
      expect(bridge.previewItems().first.title, '通知 有公告');

      final state = bridge.startPreview(0);
      final row = state.sections.first.rows.first;

      expect(state.notices, hasLength(1));
      expect(await bridge.openLink(row.id), isNull);
      expect(ui.toasts.single, startsWith('preview → $_host'));
      expect(moodle.backgrounds, isEmpty);
    });
  });
}
