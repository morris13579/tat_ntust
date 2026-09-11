import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_app/src/service/notifications.dart';

/// FCM 背景推播的進入點。
///
/// 必須是 top-level 函式並帶 `@pragma('vm:entry-point')`，不要為了整齊搬回
/// class 裡：背景推播是在另一個 isolate 由原生層「依進入點名稱」反查這個函式，
/// release 的 tree-shaking／obfuscation 會把沒標記的符號搖掉或改名（class 的
/// static method 最容易失敗）。失敗時只是背景安靜地收不到通知，背景 isolate
/// 的例外連 Crashlytics 都收不到，debug 建置也複現不出來。
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  ReceivedNotification receivedNotification = buildCloudMessageNotification(
    message,
    type: "cloud_message_background",
  );
  await Notifications.instance.showNotification(receivedNotification);
}

/// 把 [RemoteMessage] 轉成本地通知內容，前景與背景兩條路徑共用。
///
/// 兩條路徑唯一的差別是 payload 的 `type`（點擊通知後由
/// `Notifications._configureSelectNotificationSubject` 分流），共用同一個函式
/// 才不會一邊改了 fallback 另一邊忘記跟上。
///
/// 注意求值順序：`notificationId` 是會自增的計數器，這裡取一次、
/// [ReceivedNotification] 的建構子裡還會再取一次，所以 payload 裡的 `id` 比
/// 實際的通知 id 小 1。`idList` 的去重就是拿 payload 的 id 在比，不要順手
/// 「修正」成同一個值。
ReceivedNotification buildCloudMessageNotification(
  RemoteMessage message, {
  required String type,
}) {
  // data-only 的推播沒有 notification，硬解會 NPE，而背景 isolate 的
  // 例外連 Crashlytics 都收不到。
  return ReceivedNotification(
    title: message.notification?.title ?? message.data["title"]?.toString(),
    body: message.notification?.body ?? message.data["body"]?.toString(),
    payload: json.encode({
      "type": type,
      "id": Notifications.instance.notificationId,
      "data": message.data,
    }),
  );
}

class CloudMessagingUtils {
  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    /// Update the iOS foreground notification presentation options to allow
    /// heads up notifications.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((event) {
      _onMessage(event);
    });
/*
    FirebaseMessaging.onMessageOpenedApp.listen((event) {
      _onMessage(event);
    });
 */
  }

  static Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }

  static Future<void> _onMessage(RemoteMessage message) async {
    ReceivedNotification receivedNotification = buildCloudMessageNotification(
      message,
      type: "cloud_message",
    );
    await Notifications.instance.showNotification(receivedNotification);
  }
}
