import SwiftUI

enum StaggerEffect {
  /// 課表格子：從中心放大。
  case scale
  /// 清單：由下往上滑入。
  case slide
}

extension View {
  /// 照 Flutter 版 flutter_staggered_animations 的 staggeredList：一列接一列 375ms 進場。
  func staggeredAppear(_ index: Int, _ appeared: Bool, _ effect: StaggerEffect = .scale) -> some View {
    opacity(appeared ? 1 : 0)
      .scaleEffect(effect == .scale && !appeared ? 0.01 : 1)
      .offset(y: effect == .slide && !appeared ? 50 : 0)
      // 延遲封頂：長清單最後幾列才不會晚好幾秒出現。
      .animation(.easeOut(duration: 0.375).delay(Double(min(index, 20)) * 0.05), value: appeared)
  }
}
