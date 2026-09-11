import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_app/src/util/cloud_messaging_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// 這組測試守住 FCM 背景 handler 的兩件事：
///
/// 1. `firebaseMessagingBackgroundHandler` 必須是 **top-level 函式**並帶
///    `@pragma('vm:entry-point')`：背景 isolate 依進入點名稱反查函式，release
///    的 tree-shake／obfuscate 會把 class 裡的 static method 改名或搖掉，
///    背景推播就此安靜消失。Dart 沒有反射可以斷言這兩件事，這裡只能釘住簽章：
///    有人把它搬回 class 或改動參數時，型別檢查會先擋下來。
/// 2. 前景／背景兩條路徑共用 [buildCloudMessageNotification]，這裡凍結它的行為，
///    特別是 data-only 推播的 title/body fallback。
void main() {
  group('firebaseMessagingBackgroundHandler', () {
    test('簽章符合 FirebaseMessaging.onBackgroundMessage 要求的 top-level handler',
        () {
      // class 內的 static method 在型別上一樣過得了這個指派，卻在 release 的
      // 背景 isolate 解不到進入點；top-level 與 pragma 只能靠 code review 把關。
      const BackgroundMessageHandler handler =
          firebaseMessagingBackgroundHandler;
      expect(handler, isNotNull);
    });
  });

  group('buildCloudMessageNotification', () {
    test('有 notification 時優先取 notification 的 title/body', () {
      final result = buildCloudMessageNotification(
        const RemoteMessage(
          notification: RemoteNotification(title: '停課通知', body: '今日停課'),
          data: {'title': '不該被用到', 'body': '不該被用到'},
        ),
        type: 'cloud_message',
      );

      expect(result.title, '停課通知');
      expect(result.body, '今日停課');
    });

    test('data-only 推播改用 data 的 title/body，而不是硬解 notification', () {
      // data-only 推播沒有 notification 欄位，硬解會 NPE，
      // 而背景 isolate 的例外連 Crashlytics 都收不到。
      final result = buildCloudMessageNotification(
        const RemoteMessage(data: {'title': '成績更新', 'body': '微積分已登分'}),
        type: 'cloud_message_background',
      );

      expect(result.title, '成績更新');
      expect(result.body, '微積分已登分');
    });

    test('notification 與 data 都沒有時 title 是空字串、body 是 null', () {
      // ReceivedNotification 的 setter 會把 null title 轉成 ""，body 則原樣留 null。
      final result = buildCloudMessageNotification(
        const RemoteMessage(),
        type: 'cloud_message',
      );

      expect(result.title, '');
      expect(result.body, isNull);
    });

    test('data 的值不是字串時會被 toString，不會丟例外', () {
      final result = buildCloudMessageNotification(
        const RemoteMessage(data: {'title': 123, 'body': true}),
        type: 'cloud_message',
      );

      expect(result.title, '123');
      expect(result.body, 'true');
    });

    test('payload 的 type 由呼叫端決定，前景與背景各自不同', () {
      final foreground = buildCloudMessageNotification(
        const RemoteMessage(),
        type: 'cloud_message',
      );
      final background = buildCloudMessageNotification(
        const RemoteMessage(),
        type: 'cloud_message_background',
      );

      expect(json.decode(foreground.payload!)['type'], 'cloud_message');
      expect(
        json.decode(background.payload!)['type'],
        'cloud_message_background',
      );
    });

    test('payload 會原樣帶上整包 data，供點擊通知後分流使用', () {
      final result = buildCloudMessageNotification(
        const RemoteMessage(data: {'route': 'score', 'semester': '1131'}),
        type: 'cloud_message',
      );

      expect(
        json.decode(result.payload!)['data'],
        {'route': 'score', 'semester': '1131'},
      );
    });

    test('payload 的 id 比通知本身的 id 小 1（既有行為，去重靠 payload 的 id）', () {
      // notificationId 是自增計數器：這裡取一次寫進 payload，
      // ReceivedNotification 的建構子裡還會再取一次當作通知 id。
      // Notifications.idList 的去重比對的是 payload 的 id，不要「修正」成同一個。
      final result = buildCloudMessageNotification(
        const RemoteMessage(),
        type: 'cloud_message',
      );

      expect(json.decode(result.payload!)['id'], result.id - 1);
    });
  });
}
