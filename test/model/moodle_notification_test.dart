import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_notification_fixtures.dart';

/// `message_popup_get_popup_notifications` 的解析契約。
void main() {
  test('逐欄解析出三則通知', () {
    final list = MoodleNotificationList.fromJson(
        loadMoodleNotificationFixture('popup_notifications'));

    expect(list.unreadcount, 2);
    expect(list.notifications.map((n) => n.id), [101, 102, 103]);

    final assign = list.notifications.first;
    expect(assign.component, 'mod_assign');
    expect(assign.eventtype, 'assign_notification');
    expect(assign.read, isFalse);
    expect(assign.contexturl,
        'https://moodle2.ntust.edu.tw/mod/assign/view.php?id=77001');
    expect(assign.customdata, contains('feedbackavailable'));
    // fromJson 不做還原，那是 connector 的事。
    expect(assign.subject, contains('&amp;'));

    final forum = list.notifications[1];
    expect(forum.read, isTrue);
    expect(forum.timeread, 1757810000);
  });

  test('未讀的 timeread 是 null，解出來是 null 而不是拋', () {
    final list = MoodleNotificationList.fromJson(
        loadMoodleNotificationFixture('popup_notifications'));

    expect(list.notifications.first.timeread, isNull);
  });

  test('component / eventtype / contexturl / customdata 全是 null 也不拋', () {
    final list = MoodleNotificationList.fromJson(
        loadMoodleNotificationFixture('popup_notifications'));
    final core = list.notifications.last;

    expect(core.component, isNull);
    expect(core.eventtype, isNull);
    expect(core.contexturl, isNull);
    expect(core.contexturlname, isNull);
    expect(core.customdata, isNull);
    expect(core.fullmessagehtml, '');
  });

  test('缺席的欄位退回預設值，不拋', () {
    final list = MoodleNotificationList.fromJson({
      'notifications': [
        {'id': 7},
      ],
    });

    expect(list.unreadcount, 0);
    final n = list.notifications.single;
    expect(n.id, 7);
    expect(n.subject, '');
    expect(n.read, isFalse);
    expect(n.timecreated, 0);
  });

  test('toJson → fromJson round-trip 相等（快取存的就是 toJson）', () {
    final list = MoodleNotificationList.fromJson(
        loadMoodleNotificationFixture('popup_notifications'));

    final restored = MoodleNotificationList.fromJson(list.toJson());

    expect(restored.unreadcount, list.unreadcount);
    expect(restored.notifications.length, list.notifications.length);
    for (var i = 0; i < list.notifications.length; i++) {
      final a = list.notifications[i];
      final b = restored.notifications[i];
      expect(b.id, a.id);
      expect(b.subject, a.subject);
      expect(b.read, a.read);
      expect(b.timeread, a.timeread);
      expect(b.contexturl, a.contexturl);
      expect(b.component, a.component);
      expect(b.customdata, a.customdata);
      expect(b.fullmessagehtml, a.fullmessagehtml);
    }
  });
}
