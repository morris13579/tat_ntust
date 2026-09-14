import SwiftUI

/// 畫面底部那顆膠囊。版面刻意照 Flutter 版的 `TatBottomPill`：高 48（兩行字會自己長高）、
/// 左右內距 20、整顆圓；底色不反色，跟著深淺色走。
struct ToastPill: View {
  let item: ToastItem
  var dismiss: () -> Void = {}

  var body: some View {
    HStack(spacing: 8) {
      if item.sticky {
        if let progress = item.progress {
          ProgressRing(value: progress)
            .frame(width: 20, height: 20)
        } else {
          ProgressView()
            .controlSize(.small)
            .frame(width: 20, height: 20)
        }
      } else {
        LucideImage(item.icon ?? icon, size: 20)
          .foregroundStyle(iconColor)
      }
      Text(item.progress.map { "\(item.message) \(Int(($0 * 100).rounded()))%" } ?? item.message)
        .font(.body)
        .foregroundStyle(Color.primary)
        .lineLimit(2)
      if let action = item.action {
        Button {
          dismiss()
          action.run()
        } label: {
          Text(action.label)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.tatBrand)
            .padding(.leading, 4)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
    .frame(minHeight: 48)
    .pillBackground()
    .accessibilityElement(children: .combine)
  }

  private var icon: LucideIcon {
    switch item.kind {
    case .success: Lucide.circleCheck
    case .info: Lucide.info
    case .error: Lucide.triangleAlert
    }
  }

  private var iconColor: Color {
    switch item.kind {
    case .success: .green
    case .info: Color.primary
    case .error: .red
    }
  }
}

private extension View {
  /// 日間是淺色、夜間是深色的膠囊。iOS 26 用 Liquid Glass，字和圖示放在玻璃裡，底下的畫面深淺不同時系統會自己調對比。
  @ViewBuilder
  func pillBackground() -> some View {
    if #available(iOS 26, *) {
      glassEffect(.regular, in: Capsule())
    } else {
      background(.regularMaterial, in: Capsule())
        // Flutter 的 blurRadius 16 等於高斯 sigma 8，SwiftUI 的 radius 就是 sigma。
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
  }
}

/// 提示的堆疊與進度框的蓋板。全 App 只有這一處把膠囊放上畫面。
struct ToastOverlay: View {
  let presenter: UiPresenter
  /// sheet 裡的那一份：不擋點擊、不畫進度提示——那兩個屬於 sheet 底下正在等的畫面，
  /// 擋在登入 sheet 上會讓人按不到驗證碼。
  var inSheet = false
  /// sheet 自己的進度提示，排在最底下。
  var progress: String? = nil

  var body: some View {
    ZStack {
      if !inSheet && presenter.blockingCount > 0 {
        Color.black.opacity(0.001)
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {}
      }

      VStack(spacing: 8) {
        Spacer()
        ForEach(presenter.toasts.reversed().filter { !inSheet || !$0.sticky }) { item in
          ToastPill(item: item) { presenter.remove(item.id) }
            // 沒有按鈕的不吃點擊，底下的內容照樣能操作。
            .allowsHitTesting(item.action != nil)
            .transition(.opacity.combined(with: .offset(y: 8)))
        }
        if let progress {
          ToastPill(item: ToastItem(message: progress, kind: .info, autoClose: nil))
            .id(progress)
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .offset(y: 8)))
        }
      }
      .animation(.easeOut(duration: 0.16), value: progress)
      .padding(.horizontal, 24)
      .padding(.bottom, 24 + (inSheet ? 0 : presenter.bottomBarInset))
      .frame(maxWidth: .infinity, alignment: .bottom)
    }
  }
}

/// 下載膠囊的進度圈：`ProgressView` 的圓形樣式在 iOS 不吃進度值，只會一直轉。
private struct ProgressRing: View {
  let value: Double

  var body: some View {
    ZStack {
      Circle().stroke(Color.primary.opacity(0.2), lineWidth: 2.5)
      Circle()
        .trim(from: 0, to: max(0.02, value))
        .stroke(Color.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
    .padding(1)
    .animation(.linear(duration: 0.15), value: value)
  }
}
