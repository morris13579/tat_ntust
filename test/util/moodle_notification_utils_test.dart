import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/util/moodle_notification_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_notification_fixtures.dart';

/// 站內通知的純函式規格。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bodyHtmlOf', () {
    test('有 fullmessagehtml 就用它', () {
      final n = MoodleNotification(
        fullmessagehtml: '<p>正文</p>',
        text: '<p>摘要</p>',
        fullmessage: '純文字',
      );

      expect(MoodleNotificationUtils.bodyHtmlOf(n), '<p>正文</p>');
    });

    test('fullmessagehtml 還留著 @@PLUGINFILE@@ → 退回 text（那段 HTML 的圖是壞的）', () {
      final n = MoodleNotification(
        fullmessagehtml: '<img src="@@PLUGINFILE@@/a.png">',
        text: '<p>摘要</p>',
      );

      expect(MoodleNotificationUtils.bodyHtmlOf(n), '<p>摘要</p>');
    });

    test('只剩 fullmessage → 逸出後包成一段（純文字不能直接當 HTML）', () {
      final n = MoodleNotification(fullmessage: 'a < b & c');

      expect(MoodleNotificationUtils.bodyHtmlOf(n), '<p>a &lt; b &amp; c</p>');
    });

    test('三個都空 → 空字串，不拋', () {
      expect(MoodleNotificationUtils.bodyHtmlOf(MoodleNotification()), '');
    });
  });

  group('plainSummaryOf', () {
    test('smallmessage 優先，標籤剝掉、實體還原、空白收斂', () {
      final n = MoodleNotification(
        smallmessage: '<p>作業 HW1 &amp; Report\n 已評分</p>',
        fullmessage: '不該用到',
      );

      expect(MoodleNotificationUtils.plainSummaryOf(n), '作業 HW1 & Report 已評分');
    });

    test('smallmessage 空 → fullmessage → text', () {
      expect(
        MoodleNotificationUtils.plainSummaryOf(
            MoodleNotification(fullmessage: '純文字')),
        '純文字',
      );
      expect(
        MoodleNotificationUtils.plainSummaryOf(
            MoodleNotification(text: '<p>只有 text</p>')),
        '只有 text',
      );
      expect(MoodleNotificationUtils.plainSummaryOf(MoodleNotification()), '');
    });
  });

  group('customDataOf', () {
    test('null / "null" / 壞 JSON / 不是物件 一律回空 map，永不拋', () {
      for (final raw in [null, 'null', '{', '[1,2]', '']) {
        expect(
          MoodleNotificationUtils.customDataOf(
              MoodleNotification(customdata: raw)),
          isEmpty,
        );
      }
    });

    test('合法 JSON 物件解得出來', () {
      final data = MoodleNotificationUtils.customDataOf(
          MoodleNotification(customdata: '{"cmid":77001}'));

      expect(data['cmid'], 77001);
    });
  });

  group('cmidOf', () {
    test('assign 的通知拿得到 cmid，core 的通知回 null', () {
      final list = fixtureNotifications().notifications;

      expect(MoodleNotificationUtils.cmidOf(list[0]), 77001);
      expect(MoodleNotificationUtils.cmidOf(list[2]), isNull);
    });
  });

  group('openUrlOf', () {
    const host = 'moodle2.ntust.edu.tw';

    test('自家 https 回值', () {
      final n = MoodleNotification(
          contexturl: 'https://moodle2.ntust.edu.tw/mod/assign/view.php?id=1');

      expect(MoodleNotificationUtils.openUrlOf(n, siteHost: host),
          'https://moodle2.ntust.edu.tw/mod/assign/view.php?id=1');
    });

    test('http、別的 host、空與 null 一律回 null', () {
      // 通知內容指到的外站不該被當成自家頁面開，更不該套上免登入鑰匙。
      for (final url in [
        'http://moodle2.ntust.edu.tw/x',
        'https://evil.example.com/mod/assign/view.php?id=1',
        '',
        null,
      ]) {
        expect(
          MoodleNotificationUtils.openUrlOf(MoodleNotification(contexturl: url),
              siteHost: host),
          isNull,
          reason: url,
        );
      }
    });
  });

  group('sortNewestFirst', () {
    test('新的排前面，時間相同時維持原順序', () {
      final list = [
        MoodleNotification(id: 1, timecreated: 100),
        MoodleNotification(id: 2, timecreated: 300),
        MoodleNotification(id: 3, timecreated: 200),
        MoodleNotification(id: 4, timecreated: 300),
      ];

      expect(MoodleNotificationUtils.sortNewestFirst(list).map((n) => n.id),
          [2, 4, 3, 1]);
    });
  });

  group('looksDisabledByUser', () {
    test('清單空 + 未讀數 > 0 才算「使用者關掉了」', () {
      expect(
        MoodleNotificationUtils.looksDisabledByUser(
            fixtureNotifications('popup_notifications_disabled')),
        isTrue,
      );
      expect(
        MoodleNotificationUtils.looksDisabledByUser(
            fixtureNotifications('popup_notifications_none')),
        isFalse,
      );
      expect(
        MoodleNotificationUtils.looksDisabledByUser(fixtureNotifications()),
        isFalse,
      );
    });
  });

  group('formatCreatedTime', () {
    test('同一年 MM/dd HH:mm，跨年補年份', () {
      final now = DateTime(2026, 9, 6, 12, 0);

      expect(
          MoodleNotificationUtils.formatCreatedTime(
              DateTime(2026, 9, 3, 7, 5), now),
          '09/03 07:05');
      expect(
          MoodleNotificationUtils.formatCreatedTime(
              DateTime(2025, 12, 31, 23, 59), now),
          '2025/12/31 23:59');
    });
  });
}
