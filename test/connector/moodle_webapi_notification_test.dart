import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_notification_fixtures.dart';
import '../helpers/reset_statics.dart';

/// 站內通知五支 wsfunction 的本機判讀與送出參數。
///
/// 三個最容易在真機上炸掉的格子都釘在這裡：`useridto` 不可以送 0、兩支未讀數
/// 回的是**裸 JSON 數字**、mark-all 回的是**裸 bool**（沒有 warnings 外殼，
/// 所以「沒有拋例外」不等於成功）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    resetAppStatics();
    MoodleWebApiConnector.wsToken = 'token';
    // site_info 已經問過了，_ensureUserId 不會再打一趟。
    MoodleWebApiConnector.userId = '9001';
  });

  tearDown(resetAppStatics);

  /// 依序回 [responses]；回傳的清單記錄每一次送出的參數。
  List<ConnectorParameter> stubWs(List<dynamic> responses) {
    final captured = <ConnectorParameter>[];
    final queue = List<dynamic>.from(responses);
    MoodleWebApiConnector.wsPost = (parameter) async {
      captured.add(parameter);
      return queue.removeAt(0);
    };
    return captured;
  }

  List<MoodleApiException> recordApiErrors() {
    final errors = <MoodleApiException>[];
    MoodleWebApiConnector.onApiError = errors.add;
    return errors;
  }

  group('getNotifications', () {
    test('送出真的 userid、明確的 limit，而且不送 moodlewssetting*', () async {
      final captured =
          stubWs([loadMoodleNotificationFixture('popup_notifications')]);

      final list = await MoodleWebApiConnector.getNotifications();

      expect(list, isNotNull);
      final data = captured.single.data as Map;
      expect(data['wsfunction'], 'message_popup_get_popup_notifications');
      // 送 0 對這一支雖然合法，但真實 id 才是所有寫入路徑共用的那一個。
      expect(data['useridto'], '9001');
      expect(data['newestfirst'], '1');
      // limit 預設 0 ＝不限筆數，一定要自己給上限。
      expect(data['limit'], '50');
      expect(data['offset'], '0');
      expect(data.containsKey('moodlewssettingfileurl'), isFalse);
      expect(data.containsKey('moodlewssettingfilter'), isFalse);
    });

    test('accessexception → 回 null 並送出 onApiError', () async {
      stubWs([loadMoodleNotificationFixture('error_accessexception')]);
      final errors = recordApiErrors();

      expect(await MoodleWebApiConnector.getNotifications(), isNull);
      expect(errors.single.errorcode, 'accessexception');
    });

    /// `newestfirst` 回的是最新 N 則、不分已讀未讀，`unreadcount` 卻是收件匣
    /// 全部的未讀，所以視窗外還有未讀時得往下翻。
    Map<String, dynamic> page(List<int> unreadIds, List<int> readIds,
            {required int unreadcount}) =>
        {
          "notifications": [
            for (final id in [...unreadIds, ...readIds])
              {
                "id": id,
                "subject": "n$id",
                "timecreated": 1757900000 - id,
                "read": readIds.contains(id),
              },
          ],
          "unreadcount": unreadcount,
        };

    test('回滿一頁而且未讀還沒拿齊 → 用 offset 翻下一頁', () async {
      final captured = stubWs([
        page(const [], const [1, 2], unreadcount: 1),
        page(const [3], const [], unreadcount: 1),
      ]);

      final list = await MoodleWebApiConnector.getNotifications(limit: 2);

      expect(list!.notifications.map((n) => n.id), [1, 2, 3]);
      expect(list.unreadcount, 1);
      expect(captured.map((c) => (c.data as Map)['offset']), ['0', '2']);
    });

    test('未讀已經全部在手上就不再翻', () async {
      final captured = stubWs([
        page(const [1, 2], const [], unreadcount: 2)
      ]);

      final list = await MoodleWebApiConnector.getNotifications(limit: 2);

      expect(list!.notifications, hasLength(2));
      expect(captured, hasLength(1));
    });

    test('翻頁有上限，不會為了一個大收件匣打不完的請求', () async {
      final captured = stubWs([
        for (var i = 0; i < 8; i++) page(const [], [i + 1], unreadcount: 99),
      ]);

      final list = await MoodleWebApiConnector.getNotifications(limit: 1);

      expect(captured, hasLength(MoodleWebApiConnector.notificationsMaxPages));
      expect(list!.notifications, hasLength(4));
    });

    test('第二頁失敗時，第一頁照樣給畫面', () async {
      stubWs([
        page(const [], const [1, 2], unreadcount: 5),
        loadMoodleNotificationFixture('error_accessexception'),
      ]);
      final errors = recordApiErrors();

      final list = await MoodleWebApiConnector.getNotifications(limit: 2);

      expect(list!.notifications.map((n) => n.id), [1, 2]);
      expect(errors.single.errorcode, 'accessexception');
    });
  });

  group('notificationsOf', () {
    test('subject 與 contexturlname 的 HTML 實體會被還原', () {
      final list = fixtureNotifications();

      expect(list.notifications.first.subject, '作業已評分：HW1 & Report');
      expect(list.notifications.first.contexturlname, 'HW1 & Report');
      expect(list.unreadcount, 2);
    });

    test('形狀不對一律回 null，不拋', () {
      expect(MoodleWebApiConnector.notificationsOf(null), isNull);
      expect(MoodleWebApiConnector.notificationsOf(<dynamic>[]), isNull);
      expect(
          MoodleWebApiConnector.notificationsOf('<html>login</html>'), isNull);
      expect(MoodleWebApiConnector.notificationsOf({'unreadcount': 3}), isNull);
    });

    test('清單空但 unreadcount 不是 0 是合法回應（使用者關掉了站內通知）', () {
      final list = fixtureNotifications('popup_notifications_disabled');

      expect(list.notifications, isEmpty);
      expect(list.unreadcount, 4);
    });
  });

  group('preferredUnreadCountFunction', () {
    MoodleProfileEntity profileWith(List<String> functions) =>
        MoodleProfileEntity(
          functions: [
            for (final name in functions)
              MoodleProfileFunctions(name: name, version: '2024100700'),
          ],
        );

    test('site_info 還沒載入 → popup 那支（fail-open，同 wsFunctionBlocked）', () {
      MoodleWebApiConnector.siteInfo = null;

      expect(MoodleWebApiConnector.preferredUnreadCountFunction(),
          MoodleWebApiConnector.popupUnreadCountFunction);
    });

    test('兩支都有 → popup 優先，與官方 App 相反是刻意的', () {
      // TAT 的清單只顯示 popup 通知；用 core_ 的總數會出現
      // 「紅點 3、點進去只有 1 則未讀」。
      MoodleWebApiConnector.siteInfo = profileWith([
        MoodleWebApiConnector.popupUnreadCountFunction,
        MoodleWebApiConnector.unreadNotificationCountFunction,
      ]);

      expect(MoodleWebApiConnector.preferredUnreadCountFunction(),
          MoodleWebApiConnector.popupUnreadCountFunction);
    });

    test('只有 core_message 那支 → 退而用它（超集，可能高估）', () {
      MoodleWebApiConnector.siteInfo = profileWith([
        MoodleWebApiConnector.unreadNotificationCountFunction,
      ]);

      expect(MoodleWebApiConnector.preferredUnreadCountFunction(),
          MoodleWebApiConnector.unreadNotificationCountFunction);
    });

    test('兩支都沒有 → null（不打，紅點交給清單自帶的 unreadcount）', () async {
      MoodleWebApiConnector.siteInfo =
          profileWith(['core_course_get_contents']);
      final captured = stubWs([]);

      expect(MoodleWebApiConnector.preferredUnreadCountFunction(), isNull);
      expect(await MoodleWebApiConnector.getUnreadNotificationCount(), isNull);
      expect(captured, isEmpty);
    });
  });

  group('getUnreadNotificationCount', () {
    test('送真的 userid（送 0 會被伺服器判 accessdenied）', () async {
      final captured = stubWs([7]);

      expect(await MoodleWebApiConnector.getUnreadNotificationCount(), 7);
      final data = captured.single.data as Map;
      expect(data['wsfunction'],
          'message_popup_get_unread_popup_notification_count');
      expect(data['useridto'], '9001');
    });

    test('unreadCountOf 吃裸數字、浮點與字串，其餘回 null', () {
      expect(MoodleWebApiConnector.unreadCountOf(5), 5);
      expect(MoodleWebApiConnector.unreadCountOf(5.0), 5);
      expect(MoodleWebApiConnector.unreadCountOf('5'), 5);
      expect(MoodleWebApiConnector.unreadCountOf('x'), isNull);
      expect(MoodleWebApiConnector.unreadCountOf(null), isNull);
      expect(MoodleWebApiConnector.unreadCountOf({'count': 5}), isNull);
    });

    test('0 是合法答案，不是失敗', () async {
      stubWs([0]);

      expect(await MoodleWebApiConnector.getUnreadNotificationCount(), 0);
    });
  });

  group('markNotificationRead', () {
    test('只送 notificationid（timeread 省略，伺服器用 time()）', () async {
      final captured = stubWs([
        {'notificationid': 101, 'warnings': []}
      ]);

      expect(await MoodleWebApiConnector.markNotificationRead(101), isTrue);
      final data = captured.single.data as Map;
      expect(data['wsfunction'], 'core_message_mark_notification_read');
      expect(data['notificationid'], '101');
      expect(data.containsKey('timeread'), isFalse);
    });

    test('通知早被清理排程刪掉（dml_missing_record_exception）→ false，不拋', () async {
      stubWs([
        {
          'exception': 'dml_missing_record_exception',
          'errorcode': 'invalidrecord',
          'message':
              'Can not find data record in database table notifications.',
        }
      ]);
      final errors = recordApiErrors();

      expect(await MoodleWebApiConnector.markNotificationRead(101), isFalse);
      expect(errors.single.errorcode, 'invalidrecord');
    });
  });

  group('markAllNotificationsRead', () {
    test('送真的 userid，伺服器回裸 true → true', () async {
      final captured = stubWs([true]);

      expect(await MoodleWebApiConnector.markAllNotificationsRead(), isTrue);
      final data = captured.single.data as Map;
      expect(data['wsfunction'], 'core_message_mark_all_notifications_as_read');
      // useridto 與 useridfrom 都是 0 時伺服器判 accessdenied。
      expect(data['useridto'], '9001');
    });

    test('伺服器回裸 false → false（沒有拋例外不等於成功）', () async {
      stubWs([false]);

      expect(await MoodleWebApiConnector.markAllNotificationsRead(), isFalse);
    });
  });

  test('站台沒開放這支 function 時在送出前就擋下來', () async {
    MoodleWebApiConnector.siteInfo = MoodleProfileEntity(
      functions: [
        MoodleProfileFunctions(
            name: 'core_course_get_contents', version: '2024100700'),
      ],
    );
    final captured = stubWs([]);
    final errors = recordApiErrors();

    expect(await MoodleWebApiConnector.getNotifications(), isNull);
    expect(captured, isEmpty);
    expect(errors.single.skippedBeforeRequest, isTrue);
    expect(errors.single.message, contains('站台未對這個 token 開放'));
  });
}
