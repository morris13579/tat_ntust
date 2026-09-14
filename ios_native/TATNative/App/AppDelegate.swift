import Firebase
import UIKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
  let app = AppEnvironment()

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    BackIndicator.install()
    // 要排在引擎之前：Dart 的 Firebase.initializeApp 會接上這個 default app；反過來的話
    // 原生的 Crashlytics 抓不到啟動早期的當機。
    FirebaseApp.configure()
    app.push.configure(application)
    app.start()
    return true
  }

  func application(
    _ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    app.push.didRegister(deviceToken: deviceToken)
  }
}
