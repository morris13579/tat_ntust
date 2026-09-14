import SwiftUI

extension View {
  /// 畫面上的主要動作：iOS 26 用 Liquid Glass，之前用實心的系統樣式。
  @ViewBuilder
  func prominentButtonStyle() -> some View {
    if #available(iOS 26, *) {
      buttonStyle(.glassProminent)
    } else {
      buttonStyle(.borderedProminent)
    }
  }
}
