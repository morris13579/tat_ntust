import FirebaseAnalytics
import SwiftUI

/// Firebase Analytics。名稱照 Flutter 版：分頁用 `MainTab` 的名字、推進去的頁用 GetX 的路由名（`/類別名`），
/// 既有的報表才接得起來。
enum AppAnalytics {
  static func screen(_ name: String) {
    Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: name])
  }

  static func fileDownload() {
    Analytics.logEvent("file_download", parameters: nil)
  }
}

extension View {
  /// 這一頁出現時記一次；從下一頁退回來也再記一次，同 `FirebaseAnalyticsObserver`。
  func analyticsScreen(_ name: String) -> some View {
    onAppear { AppAnalytics.screen(name) }
  }
}
