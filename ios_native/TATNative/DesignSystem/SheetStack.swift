import SwiftUI

/// sheet 的外框：導覽列放標題與關閉鈕，把手、圓角與底色交給系統。放在 `.sheet { }` 的最外層，
/// 內容通常是一個 `List`。高度跟著內容，比螢幕高就是整頁、可以捲；上下的留白由這裡統一給。
struct SheetStack<Content: View>: View {
  var title: String?
  var closeLabel = L10n.close
  @ViewBuilder var content: () -> Content
  @Environment(\.dismiss) private var dismiss
  @State private var height: CGFloat?

  var body: some View {
    NavigationStack {
      titled
        // 清單預設在第一段上面留一段標題的高度、段與段之間也隔很開，放在 sheet 裡就像多出一塊空白。
        .contentMargins(.vertical, 12, for: .scrollContent)
        .listSectionSpacing(.compact)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { SheetCloseButton(label: closeLabel) { dismiss() } }
        .modifier(ContentHeightReader(height: $height))
    }
    .presentationDetents(detents)
    .presentationDragIndicator(.visible)
  }

  private var detents: Set<PresentationDetent> {
    guard let height else { return [.medium, .large] }
    return [.height(height.rounded())]
  }

  @ViewBuilder private var titled: some View {
    if let title {
      content().navigationTitle(title)
    } else {
      content()
    }
  }
}

/// 捲動內容連同上下內距，扣掉底部安全區域，就是 `.height` 要的值。安全區域取視窗的、不取 sheet 自己的：
/// sheet 還在動的時候，它自己的底部安全區域與內距各自在 0 與 34 之間跳，兩個一減會多出一段，
/// 內容接近整頁時就先撐成不透明的整頁、再縮回玻璃，看起來像閃一下。iOS 17 量不到，sheet 維持半頁與整頁兩段。
private struct ContentHeightReader: ViewModifier {
  @Binding var height: CGFloat?

  func body(content: Content) -> some View {
    if #available(iOS 18, *) {
      let homeIndicator = Self.windowBottomInset
      content.onScrollGeometryChange(for: CGFloat?.self) { geometry in
        guard geometry.contentSize.height > 0 else { return nil }
        // 清單的上下留白算在內容裡，ScrollView 的算在內距裡；內距扣掉安全區域剩下的就是底部留白。
        let bottom = homeIndicator.map { max(0, geometry.contentInsets.bottom - $0) } ?? 0
        return geometry.contentSize.height + geometry.contentInsets.top + bottom
      } action: { _, value in
        if let value { height = value }
      }
    } else {
      content
    }
  }

  private static var windowBottomInset: CGFloat? {
    UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.windows.first }
      .first?.safeAreaInsets.bottom
  }
}
