import SwiftUI

/// 區塊裡的空狀態：一個圖示、一句話，照 Flutter 版的 `SectionEmptyState`。
struct SectionEmptyState: View {
  let message: String
  let icon: LucideIcon

  var body: some View {
    VStack(spacing: 10) {
      LucideImage(icon, size: 28)
        .foregroundStyle(.secondary)
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
  }
}
