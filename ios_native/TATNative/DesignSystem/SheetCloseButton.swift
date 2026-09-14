import SwiftUI

/// sheet 左上角的關閉鈕：Lucide 的 x。圖示沒有字，VoiceOver 靠 `label` 唸。
struct SheetCloseButton: ToolbarContent {
  var label = L10n.cancel
  let action: () -> Void

  var body: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button(action: action) {
        LucideImage(Lucide.x, size: 20)
      }
      .accessibilityLabel(label)
      .toolbarButtonTint()
    }
  }
}
