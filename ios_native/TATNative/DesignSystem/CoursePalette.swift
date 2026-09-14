import SwiftUI

/// 課表色塊。和 Flutter 版的 `UIUtils.generateHarmoniousColors` 同一個想法：從品牌色相繞一圈、低彩度。
/// 格子上的字一律是黑的，所以深色模式也是淺底，只把亮度壓低一點免得刺眼。
enum CoursePalette {
  private static let count = 12
  /// #405F90 的色相。
  private static let brandHue = 216.75

  /// 格子上的字。
  static let foreground = Color.black

  /// 格子的底色，也是詳情色帶的底色。
  static func color(for order: Int64) -> Color {
    dynamic(order) { dark, hue in
      dark
        ? UIColor(hue: hue, saturation: 0.2, brightness: 0.84, alpha: 1)
        : UIColor(hue: hue, saturation: 0.13, brightness: 0.95, alpha: 1)
    }
  }

  /// 模擬課表的草稿格：比實際的課更淡，兩種模式都是淺底。
  static func draftColor(for order: Int64) -> Color {
    dynamic(order) { dark, hue in
      dark
        ? UIColor(hue: hue, saturation: 0.1, brightness: 0.9, alpha: 1)
        : UIColor(hue: hue, saturation: 0.06, brightness: 0.98, alpha: 1)
    }
  }

  /// 詳情色帶上的字：同一個色相壓深。底色兩種模式都是淺的，字也就不必跟著換。
  static func bandForeground(for order: Int64) -> Color {
    Color(uiColor: UIColor(hue: hue(order), saturation: 0.62, brightness: 0.34, alpha: 1))
  }

  /// 依課號在課表裡的順序挑色相。乘 5 再取餘數，相鄰的課不會拿到相鄰的色相。
  private static func hue(_ order: Int64) -> CGFloat {
    let slot = Int(((order % Int64(count)) + Int64(count)) % Int64(count)) * 5 % count
    return (brandHue + Double(slot) * 360 / Double(count + 1)).truncatingRemainder(dividingBy: 360) / 360
  }

  private static func dynamic(_ order: Int64, _ make: @escaping (Bool, CGFloat) -> UIColor) -> Color {
    let hue = hue(order)
    return Color(uiColor: UIColor { make($0.userInterfaceStyle == .dark, hue) })
  }
}
