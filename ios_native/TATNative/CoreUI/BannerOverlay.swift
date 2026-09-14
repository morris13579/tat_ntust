import SwiftUI

/// 從畫面上緣落下來的提示，照 Flutter 版的 `InAppBanner`：toast 確認剛完成的動作，這一個是
/// 「剛發生了一件事，你可能想去看」——停五秒、點得下去、往上滑掉，和系統推播同一個樣子。
struct BannerOverlay: View {
  let presenter: UiPresenter
  @State private var drag: CGFloat = 0

  var body: some View {
    VStack {
      if let item = presenter.banner {
        card(item)
          .offset(y: min(drag, 0))
          .simultaneousGesture(
            DragGesture(minimumDistance: 8)
              .onChanged { drag = $0.translation.height }
              .onEnded { value in
                if value.translation.height < -24 { presenter.dismissBanner() }
                withAnimation(.easeOut(duration: 0.2)) { drag = 0 }
              }
          )
          .transition(.move(edge: .top).combined(with: .opacity))
          .id(item.id)
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
  }

  private func card(_ item: BannerItem) -> some View {
    Button {
      presenter.dismissBanner()
      item.onTap()
    } label: {
      HStack(alignment: .top, spacing: 12) {
        LucideImage(item.icon, size: 20)
          .foregroundStyle(Color.tatBrand)
        VStack(alignment: .leading, spacing: 2) {
          Text(item.title)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(item.message)
            .font(.body)
            .foregroundStyle(Color.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
      .bannerBackground()
      .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
  }
}

private extension View {
  @ViewBuilder
  func bannerBackground() -> some View {
    if #available(iOS 26, *) {
      glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    } else {
      background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 9, y: 6)
    }
  }
}
