import SwiftUI

extension View {
  /// 導覽列上的按鈕，圖示與文字都套。iOS 26 的系統返回鍵是單色的，其他按鈕跟著用文字主色，整條導覽列才是同一個顏色；
  /// 更早的系統返回鍵跟著品牌色走，就不動。有字的主要動作（寄出）用 `prominentButtonStyle()`，不套這個。
  @ViewBuilder
  func toolbarButtonTint() -> some View {
    if #available(iOS 26, *) {
      // `Color.primary` 在玻璃按鈕裡會被畫成淡灰色，自己畫的圖示看起來像停用，要指定 UIKit 的 label 色。
      tint(Color(.label))
    } else {
      self
    }
  }
}
