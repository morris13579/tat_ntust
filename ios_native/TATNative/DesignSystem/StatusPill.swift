import SwiftUI

/// 狀態籤的語意，照 Flutter 版的 `StatusPillTone`。配色由這裡決定，呼叫端只說是什麼狀態。
enum PillTone {
  /// 沒有事情要做（不需繳交、等老師評分）。
  case pending
  /// 已經送出去，等對方處理。
  case submitted
  /// 動了但還沒送出去。
  case draft
  /// 球還在使用者手上，而且時間在走。
  case attention
  case graded
  case overdue
}

/// 段標題右邊、清單列右邊那顆狀態籤。資料來自快取時整顆換成提醒色，前面多一個時鐘。
struct StatusPill: View {
  let label: String
  let tone: PillTone
  var stale = false

  var body: some View {
    HStack(spacing: 4) {
      if stale {
        LucideImage(Lucide.history, size: 12)
      }
      Text(label)
        .font(.caption.weight(.medium))
    }
    .foregroundStyle(colors.foreground)
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(colors.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  private var colors: (background: Color, foreground: Color) {
    if stale { return (Color(.systemOrange).opacity(0.15), Color(.systemOrange)) }
    return switch tone {
    case .pending: (Color(.tertiarySystemFill), Color.secondary)
    case .submitted: (Color.tatBrand.opacity(0.14), Color.tatBrand)
    case .draft: (Color(.systemPurple).opacity(0.14), Color(.systemPurple))
    case .attention: (Color(.systemOrange).opacity(0.15), Color(.systemOrange))
    case .graded: (Color(.systemGreen).opacity(0.15), Color(.systemGreen))
    case .overdue: (Color(.systemRed).opacity(0.14), Color(.systemRed))
    }
  }
}
