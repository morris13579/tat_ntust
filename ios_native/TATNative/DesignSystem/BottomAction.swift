import SwiftUI

extension View {
  /// 頁面底部固定的主要按鈕，例如篩選頁的「套用」。
  func bottomAction(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
    pinnedBottomBar {
      Button(action: action) {
        Text(title).frame(maxWidth: .infinity)
      }
      .prominentButtonStyle()
      .controlSize(.large)
      .disabled(!isEnabled)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
  }
}
