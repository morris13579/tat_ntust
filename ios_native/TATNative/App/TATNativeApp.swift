import SwiftUI

@main
struct TATNativeApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      RootView()
        .coreUi(appDelegate.app.presenter)
        .environment(appDelegate.app)
        .brandTint()
    }
    .onChange(of: scenePhase) { _, phase in
      // 回到背景就是小工具要被看到的時候，把這一刻的課表寫給它。
      if phase == .background { appDelegate.app.refreshWidgets() }
    }
  }
}
