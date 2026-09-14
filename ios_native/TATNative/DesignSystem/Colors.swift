import SwiftUI
import UIKit

extension Color {
  /// 品牌色，當 tint 與實心鈕的底，跟著「主題顏色」的設定走。在 view 裡讀到它，換色時那個 view 就會重畫。
  static var tatBrand: Color { BrandPalette.shared.color }
}

extension View {
  /// 整個 App 的 tint。包成 modifier 才會在換主題顏色時跟著更新。
  func brandTint() -> some View {
    modifier(BrandTint())
  }
}

private struct BrandTint: ViewModifier {
  func body(content: Content) -> some View {
    content.tint(Color.tatBrand)
  }
}

/// 主題顏色。沒選過用預設的品牌色：淺色是 Flutter 版在 iOS 上的 primary（seed #1565C0 的 tonal 40）；深色不用 Material 的
/// tonal 80：那是配深色字的粉藍，iOS 的實心鈕與選取的圓上面是白字，會淡到看不清。
/// 自己選的顏色保留色相與飽和度，深淺色各自把亮度拉進看得清楚的範圍：白字壓在上面、它當文字壓在底色上都要讀得到。
@Observable
final class BrandPalette {
  static let shared = BrandPalette()

  /// 設定裡存的 ARGB，nil 是預設色。
  private(set) var seed: Int64?
  private(set) var color = BrandPalette.color(for: nil)

  /// 選擇器上顯示的原色：選了太淺的顏色時，品牌色會被調深，選擇器不能跟著跳。
  var seedColor: Color? {
    seed.map { Color(uiColor: UIColor(argb: $0)) }
  }

  func apply(_ seed: Int64?) {
    guard seed != self.seed else { return }
    self.seed = seed
    color = Self.color(for: seed)
  }

  static func color(for seed: Int64?) -> Color {
    guard let seed else { return Color(uiColor: defaultColor) }
    let base = UIColor(argb: seed)
    let light = base.withLuminance(in: 0...0.25)
    let dark = base.withLuminance(in: 0.19...0.30)
    return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
  }

  static func argb(of color: Color) -> Int64 {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    func byte(_ value: CGFloat) -> Int64 { Int64((min(max(value, 0), 1) * 255).rounded()) }
    return 0xFF00_0000 | byte(red) << 16 | byte(green) << 8 | byte(blue)
  }

  private static let defaultColor = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 74 / 255, green: 131 / 255, blue: 217 / 255, alpha: 1)
      : UIColor(red: 64 / 255, green: 95 / 255, blue: 144 / 255, alpha: 1)
  }
}

private extension UIColor {
  convenience init(argb: Int64) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255, green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255, alpha: 1)
  }

  /// 保留色相與飽和度，只調 HSL 的明度，讓 WCAG 相對亮度落進 `range`；本來就在範圍裡的原樣回傳。
  func withLuminance(in range: ClosedRange<CGFloat>) -> UIColor {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    let current = Self.luminance(red, green, blue)
    guard !range.contains(current) else { return self }
    let target = current < range.lowerBound ? range.lowerBound : range.upperBound
    let (hue, saturation, _) = Self.hsl(red, green, blue)
    var low: CGFloat = 0
    var high: CGFloat = 1
    for _ in 0..<24 {
      let mid = (low + high) / 2
      let (r, g, b) = Self.rgb(hue, saturation, mid)
      if Self.luminance(r, g, b) < target { low = mid } else { high = mid }
    }
    let (r, g, b) = Self.rgb(hue, saturation, (low + high) / 2)
    return UIColor(red: r, green: g, blue: b, alpha: 1)
  }

  static func luminance(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGFloat {
    func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  }

  static func hsl(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
    let top = max(r, g, b)
    let bottom = min(r, g, b)
    let lightness = (top + bottom) / 2
    let delta = top - bottom
    guard delta > 0 else { return (0, 0, lightness) }
    let saturation = delta / (1 - abs(2 * lightness - 1))
    var hue: CGFloat =
      switch top {
      case r: ((g - b) / delta).truncatingRemainder(dividingBy: 6)
      case g: (b - r) / delta + 2
      default: (r - g) / delta + 4
      }
    hue /= 6
    if hue < 0 { hue += 1 }
    return (hue, saturation, lightness)
  }

  static func rgb(_ hue: CGFloat, _ saturation: CGFloat, _ lightness: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
    let chroma = (1 - abs(2 * lightness - 1)) * saturation
    let sector = hue * 6
    let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
    let (r, g, b): (CGFloat, CGFloat, CGFloat) =
      switch sector {
      case ..<1: (chroma, x, 0)
      case ..<2: (x, chroma, 0)
      case ..<3: (0, chroma, x)
      case ..<4: (0, x, chroma)
      case ..<5: (x, 0, chroma)
      default: (chroma, 0, x)
      }
    let m = lightness - chroma / 2
    return (r + m, g + m, b + m)
  }
}
