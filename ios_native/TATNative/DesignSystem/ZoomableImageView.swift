import SwiftUI

/// 全螢幕看一張圖：捏合放大、放大後拖曳、點兩下切換，照 Flutter 版的 `PhotoView`。
struct ZoomableImageView: View {
  let url: URL
  @Environment(\.dismiss) private var dismiss
  @State private var scale: CGFloat = 1
  @State private var settledScale: CGFloat = 1
  @State private var offset: CGSize = .zero
  @State private var settledOffset: CGSize = .zero

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color.black.ignoresSafeArea()
      AsyncImage(url: url) { phase in
        if let image = phase.image {
          image
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnify.simultaneously(with: drag))
            .onTapGesture(count: 2) {
              withAnimation(.easeOut(duration: 0.2)) { toggleZoom() }
            }
        } else if phase.error != nil {
          LucideImage(Lucide.imageOff, size: 32).foregroundStyle(.white.opacity(0.7))
        } else {
          ProgressView().tint(.white)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      Button {
        dismiss()
      } label: {
        LucideImage(Lucide.x, size: 22)
          .foregroundStyle(.white)
          .frame(width: 44, height: 44)
          .background(.black.opacity(0.4), in: Circle())
      }
      .accessibilityLabel(L10n.close)
      .padding(16)
    }
    .statusBarHidden()
  }

  private var magnify: some Gesture {
    MagnifyGesture()
      .onChanged { value in scale = min(max(1, settledScale * value.magnification), 5) }
      .onEnded { _ in
        settledScale = scale
        guard scale <= 1 else { return }
        withAnimation { offset = .zero }
        settledOffset = .zero
      }
  }

  private var drag: some Gesture {
    DragGesture()
      .onChanged { value in
        guard scale > 1 else { return }
        offset = CGSize(
          width: settledOffset.width + value.translation.width,
          height: settledOffset.height + value.translation.height)
      }
      .onEnded { _ in settledOffset = offset }
  }

  private func toggleZoom() {
    if scale > 1 {
      scale = 1
      settledScale = 1
      offset = .zero
      settledOffset = .zero
    } else {
      scale = 2.5
      settledScale = 2.5
    }
  }
}
