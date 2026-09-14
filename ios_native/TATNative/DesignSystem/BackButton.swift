import SwiftUI
import UIKit

/// 返回鍵的箭頭。系統的返回鍵在啟動時換成這張（`install()`），自己放的 `BackButton` 也用同一張，
/// 兩種返回鍵才看不出差別。Lucide 的箭頭只佔方塊中間一小塊，要放大才跟系統箭頭一樣醒目。
@MainActor
enum BackIndicator {
  static let image = Lucide.chevronLeft.uiImage(size: 28)

  static func install() {
    UINavigationBar.appearance().backIndicatorImage = image
    UINavigationBar.appearance().backIndicatorTransitionMaskImage = image
  }
}

/// 要先攔下返回（未存的草稿、送出中）的頁面，隱藏系統返回鍵之後放這個。
struct BackButton: ToolbarContent {
  var isEnabled = true
  let action: () -> Void

  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button(action: action) {
        Image(uiImage: BackIndicator.image)
      }
      .accessibilityLabel(L10n.back)
      .disabled(!isEnabled)
      .toolbarButtonTint()
    }
  }
}
