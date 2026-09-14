import SwiftUI

/// 清單裡的單選列，iOS 設定頁那種右邊打勾。
struct CheckRow: View {
  let label: String
  var supporting: String?
  var icon: LucideIcon?
  /// 整欄都是數字時（學期）用等寬數字，位數才對得齊。
  var tabularFigures = false
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        if let icon {
          LucideImage(icon, size: 20)
            .foregroundStyle(Color.tatBrand)
        }
        // 在清單的按鈕裡 `.secondary` 會跟著按鈕染成品牌色的淡色，所以次要文字指名系統色。
        VStack(alignment: .leading, spacing: 2) {
          Text(label)
            .font(tabularFigures ? .body.monospacedDigit() : .body)
            .foregroundStyle(Color.primary)
          if let supporting {
            Text(supporting)
              .font(.subheadline)
              .foregroundStyle(Color(.secondaryLabel))
          }
        }
        Spacer(minLength: 0)
        if isSelected {
          LucideImage(Lucide.check, size: 20)
            .foregroundStyle(Color.tatBrand)
        }
      }
      .contentShape(Rectangle())
    }
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
