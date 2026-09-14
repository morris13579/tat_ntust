import SwiftUI

/// 一張圓角卡片，內容由上往下排，照 Flutter 版的 `SectionCard`。
struct SectionCard<Content: View>: View {
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(
      Color(.secondarySystemGroupedBackground), in: ListGroupShape.card)
  }
}

/// 卡片裡的一列「標籤：值」，照 `SectionField`。
struct LabeledValueRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer(minLength: 8)
      Text(value)
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
  }
}

/// 卡片裡的一句說明，照 `InlineNote`：擋住動作的那一種用紅色。
struct InlineNote: View {
  let text: String
  var blocking = false

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      LucideImage(blocking ? Lucide.circleAlert : Lucide.info, size: 14)
        .alignedToFirstTextLine(.footnote)
      Text(text)
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .foregroundStyle(blocking ? Color(.systemRed) : Color.secondary)
  }
}

/// 卡片裡的小標，照 `SectionSubLabel`。
struct SectionSubLabel: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.secondary)
  }
}

/// 帶圖示的段標題，右邊可以放一顆籤。
struct IconSectionHeader<Trailing: View>: View {
  let icon: LucideIcon
  let title: String
  var first = false
  @ViewBuilder var trailing: () -> Trailing

  var body: some View {
    HStack(spacing: 8) {
      LucideImage(icon, size: 17)
      Text(title)
        .font(.sectionHeader)
      Spacer(minLength: 8)
      trailing()
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, 4)
    .padding(.top, first ? 4 : 24)
    .padding(.bottom, 8)
  }
}

extension IconSectionHeader where Trailing == EmptyView {
  init(icon: LucideIcon, title: String, first: Bool = false) {
    self.init(icon: icon, title: title, first: first) { EmptyView() }
  }
}
