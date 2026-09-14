import SwiftUI

/// 區塊標題，右邊可以帶件數，照 Flutter 版的 `SectionHeader`。整頁第一塊用窄的上距。
struct SectionHeader: View {
  let title: String
  var count: Int?
  var first = false
  var icon: LucideIcon?
  /// 右邊的字；有給就不顯示 `count`。
  var trailing: String?

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      if let icon {
        LucideImage(icon, size: 16)
          .foregroundStyle(.secondary)
          .alignedToFirstTextLine(.headline)
      }
      Text(title)
        .font(.sectionHeader)
        .foregroundStyle(.secondary)
      Spacer(minLength: 8)
      if let trailing {
        Text(trailing)
          .font(.footnote.monospacedDigit())
          .foregroundStyle(.secondary)
      } else if let count {
        Text(L10n.itemCount(String(count)))
          .font(.footnote.monospacedDigit())
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 4)
    .padding(.top, first ? 8 : 24)
    .padding(.bottom, 8)
  }
}

extension Font {
  /// 不在 `List` 裡的段標題，跟同一版系統的清單段標題一樣大：iOS 26 是 Headline，之前是 Footnote。
  static var sectionHeader: Font {
    if #available(iOS 26, *) { return .headline }
    return .footnote.weight(.semibold)
  }
}
