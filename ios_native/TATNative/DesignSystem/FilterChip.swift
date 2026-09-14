import SwiftUI

/// 篩選籤，照 Flutter 版的 `TatFilterChip`：沒選是描邊，選中是品牌色淡底加打勾。
struct FilterChip: View {
  let label: String
  var icon: LucideIcon?
  let isOn: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if isOn {
          LucideImage(Lucide.check, size: 16)
        } else if let icon {
          LucideImage(icon, size: 16)
        }
        Text(label)
          .font(.subheadline.weight(.medium))
      }
      .foregroundStyle(isOn ? Color.tatBrand : Color.primary)
      .padding(.horizontal, 12)
      .frame(minHeight: 34)
      .background(isOn ? Color.tatBrand.opacity(0.14) : Color.clear, in: Capsule())
      .overlay {
        Capsule().strokeBorder(Color(.separator), lineWidth: isOn ? 0 : 1)
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isOn ? .isSelected : [])
  }
}
