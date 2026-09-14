import SwiftUI

enum NoticeKind {
  case info, warning, error
}

/// 一條提示：圖示、一句話，右邊可以帶一個動作，照 Flutter 版的 `NoticeBar`。
struct NoticeBar: View {
  let message: String
  var kind: NoticeKind = .info
  var icon: LucideIcon?
  var actionLabel: String?
  /// 放在 `List` 裡時整列就是這條提示：底色交給列背景，圓角、內距與高度跟著清單走。
  var inList = false
  var action: (() -> Void)?

  var body: some View {
    if inList {
      content.listRowBackground(tint.opacity(0.12))
    } else {
      content
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12))
    }
  }

  private var content: some View {
    HStack(spacing: 8) {
      LucideImage(icon ?? defaultIcon, size: 16)
        .foregroundStyle(tint)
      Text(message)
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
      if let actionLabel, let action {
        Button(actionLabel, action: action)
          .font(.footnote.weight(.semibold))
          .tint(tint)
      }
    }
  }

  private var defaultIcon: LucideIcon {
    switch kind {
    case .info: Lucide.info
    case .warning: Lucide.triangleAlert
    case .error: Lucide.circleAlert
    }
  }

  private var tint: Color {
    switch kind {
    case .info: Color.tatBrand
    case .warning: Color(.systemOrange)
    case .error: Color(.systemRed)
    }
  }
}
