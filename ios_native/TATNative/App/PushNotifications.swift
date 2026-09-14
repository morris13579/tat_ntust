import FirebaseMessaging
import UIKit
import UserNotifications

/// 推播，照 `CloudMessagingUtils`：前景收到也照樣跳橫幅，權限在進主畫面時要。點推播不做任何事，
/// 與 Flutter 版相同；下載完成的本機通知點了打開檔案。Messaging 在原生版是 Swift 的責任（見 `CorePluginRegistrant.m`）。
@MainActor
final class PushNotifications: NSObject, UNUserNotificationCenterDelegate {
  func configure(_ application: UIApplication) {
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
  }

  /// 系統只問一次，之後每次呼叫都直接回答，所以每次進主畫面都叫也沒關係。
  func requestAuthorization() async {
    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
  }

  func didRegister(deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
  }

  /// 開發者選單複製用。
  func token() async -> String? {
    try? await Messaging.messaging().token()
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .badge, .sound]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    guard let path = response.notification.request.content.userInfo[DownloadFeedback.fileKey] as? String else {
      return
    }
    await FileDownloads.preview(URL(fileURLWithPath: path))
  }
}
