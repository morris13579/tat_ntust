import CoreText
import SwiftUI

/// Lucide 圖示的碼位。常數在 `Resources/Generated/Lucide.swift`，由 `tool/gen_lucide_icons.py`
/// 掃 `Lucide.xxx` 的用法產生。
struct LucideIcon: Hashable, Sendable {
  let codepoint: UInt32

  init(_ codepoint: UInt32) {
    self.codepoint = codepoint
  }
}

enum LucideWeight: Sendable {
  /// 1.5px，App 預設。
  case regular
  /// 1.0px。
  case thin
}

/// 和 Flutter 版同一份字體檔，字形照 Flutter `Icon` 的方式放進 size × size 的方塊：
/// 行高等於字級、水平依字寬置中。尺寸跟著 Dynamic Type 縮放。
struct LucideImage: View {
  private let icon: LucideIcon
  private let weight: LucideWeight
  @ScaledMetric private var size: CGFloat

  init(_ icon: LucideIcon, size: CGFloat = 20, weight: LucideWeight = .regular) {
    self.icon = icon
    self.weight = weight
    _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
  }

  var body: some View {
    LucideGlyph(icon: icon, weight: weight)
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}

extension LucideIcon {
  /// 給只收 `UIImage` 的地方（分頁列）。template 模式，顏色跟著系統走。
  func uiImage(size: CGFloat = 24, weight: LucideWeight = .regular) -> UIImage {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let path = LucideGlyph(icon: self, weight: weight).path(in: rect).cgPath
    let image = UIGraphicsImageRenderer(size: rect.size).image { context in
      context.cgContext.addPath(path)
      context.cgContext.fillPath()
    }
    return image.withRenderingMode(.alwaysTemplate)
  }

  /// 系統選單裡的破壞性動作（刪除）：選單把 template 圖示染成選單的 tint，不會跟著文字變紅，所以直接給紅色的圖。
  func destructiveUIImage() -> UIImage {
    uiImage().withTintColor(.systemRed, renderingMode: .alwaysOriginal)
  }
}

extension LucideIcon {
  /// 分頁列選到時的實心版。Lucide 沒有實心圖示，從字形推：圍起來的地方填滿，被包在裡面的線條
  /// （表格的格線、信封的摺線、日曆的點）挖成縫，碰得到外面的線條照舊，形狀才跟線條版一致。
  @MainActor
  func filledUIImage(size: CGFloat = 24) -> UIImage {
    let key = FilledKey(icon: self, size: size)
    if let cached = filledCache[key] { return cached }
    let image = renderFilled(size: size)
    filledCache[key] = image
    return image
  }

  private func renderFilled(size: CGFloat) -> UIImage {
    let scale = max(UITraitCollection.current.displayScale, 2)
    let out = Int((size * scale).rounded())
    let factor = 4
    let n = out * factor

    // 放大 factor 倍畫字形，第 0 列是上緣。
    var pixels = [UInt8](repeating: 0, count: n * n)
    pixels.withUnsafeMutableBytes { buffer in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n,
          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
      else { return }
      context.translateBy(x: 0, y: CGFloat(n))
      context.scaleBy(x: 1, y: -1)
      let rect = CGRect(x: 0, y: 0, width: n, height: n)
      context.addPath(LucideGlyph(icon: self, weight: .regular).path(in: rect).cgPath)
      context.setFillColor(gray: 1, alpha: 1)
      context.fillPath()
    }
    let stroke = pixels.map { $0 > 127 }

    // 從四邊灌進去，灌得到的空白是外面。
    var outside = [Bool](repeating: false, count: n * n)
    var queue: [Int] = []
    queue.reserveCapacity(n * n)
    for i in 0..<n {
      for index in [i, (n - 1) * n + i, i * n, i * n + n - 1] where !stroke[index] && !outside[index] {
        outside[index] = true
        queue.append(index)
      }
    }
    var head = 0
    while head < queue.count {
      let index = queue[head]
      head += 1
      let x = index % n
      let y = index / n
      for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
        let nx = x + dx
        let ny = y + dy
        guard nx >= 0, nx < n, ny >= 0, ny < n else { continue }
        let next = ny * n + nx
        if !stroke[next] && !outside[next] {
          outside[next] = true
          queue.append(next)
        }
      }
    }

    // 沿著線條走到外面要幾步：一筆粗細之內的是外框，走得更遠的是包在裡面的線。
    let limit = Int((CGFloat(n) * 1.5 / 24).rounded(.up)) + 3
    let around = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
    var distance = [Int](repeating: .max, count: n * n)
    queue.removeAll(keepingCapacity: true)
    for index in 0..<(n * n) where stroke[index] {
      let x = index % n
      let y = index / n
      for (dx, dy) in around {
        let nx = x + dx
        let ny = y + dy
        if nx >= 0, nx < n, ny >= 0, ny < n, outside[ny * n + nx] {
          distance[index] = 1
          queue.append(index)
          break
        }
      }
    }
    head = 0
    while head < queue.count {
      let index = queue[head]
      head += 1
      let x = index % n
      let y = index / n
      for (dx, dy) in around {
        let nx = x + dx
        let ny = y + dy
        guard nx >= 0, nx < n, ny >= 0, ny < n else { continue }
        let next = ny * n + nx
        if stroke[next] && distance[next] > distance[index] + 1 {
          distance[next] = distance[index] + 1
          queue.append(next)
        }
      }
    }

    // 每 factor × factor 格平均成輸出的一個像素，邊緣才有反鋸齒。
    var rgba = [UInt8](repeating: 0, count: out * out * 4)
    for oy in 0..<out {
      for ox in 0..<out {
        var sum = 0
        for sy in 0..<factor {
          for sx in 0..<factor {
            let index = (oy * factor + sy) * n + (ox * factor + sx)
            if !outside[index] && !(stroke[index] && distance[index] > limit) { sum += 1 }
          }
        }
        rgba[(oy * out + ox) * 4 + 3] = UInt8(sum * 255 / (factor * factor))
      }
    }
    let image = rgba.withUnsafeMutableBytes { buffer -> CGImage? in
      CGContext(
        data: buffer.baseAddress, width: out, height: out, bitsPerComponent: 8, bytesPerRow: out * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )?.makeImage()
    }
    guard let image else { return uiImage(size: size) }
    return UIImage(cgImage: image, scale: scale, orientation: .up).withRenderingMode(.alwaysTemplate)
  }
}

extension View {
  /// 跟一段文字並排的圖示，放在 `HStack(alignment: .firstTextBaseline)` 裡用。圖示沒有文字基線，不處理的話是拿
  /// 圖示底邊去貼第一行的基線，整顆浮在字上面；這裡改成圖示的中線對齊第一行字的中線。
  func alignedToFirstTextLine(_ style: UIFont.TextStyle) -> some View {
    alignmentGuide(.firstTextBaseline) { dimensions in
      dimensions[VerticalAlignment.center] + UIFont.preferredFont(forTextStyle: style).capHeight / 2
    }
  }
}

private struct FilledKey: Hashable {
  let icon: LucideIcon
  let size: CGFloat
}

@MainActor private var filledCache: [FilledKey: UIImage] = [:]

private struct LucideGlyph: Shape {
  let icon: LucideIcon
  let weight: LucideWeight

  func path(in rect: CGRect) -> Path {
    guard let glyph = LucideFont.glyph(icon, weight) else { return Path() }
    let scale = rect.height / glyph.lineHeight
    let transform = CGAffineTransform(
      a: scale, b: 0, c: 0, d: -scale,
      tx: rect.minX + (rect.width - glyph.advance * scale) / 2,
      ty: rect.minY + glyph.ascent * scale
    )
    return Path(glyph.outline).applying(transform)
  }
}

private enum LucideFont {
  struct Glyph {
    let outline: CGPath
    let ascent: CGFloat
    let lineHeight: CGFloat
    let advance: CGFloat
  }

  // 兩個檔案的 PostScript 名稱都是 LucideVariable，用 UIAppFonts 註冊會互相蓋掉，
  // 所以直接從檔案建字型、取輪廓。
  nonisolated(unsafe) private static let regular = load("lucide-light")
  nonisolated(unsafe) private static let thin = load("lucide-thin")

  private static func load(_ name: String) -> CTFont? {
    guard let url = Bundle.main.url(forResource: name, withExtension: "ttf"),
      let provider = CGDataProvider(url: url as CFURL),
      let font = CGFont(provider)
    else { return nil }
    return CTFontCreateWithGraphicsFont(font, 1, nil, nil)
  }

  static func glyph(_ icon: LucideIcon, _ weight: LucideWeight) -> Glyph? {
    guard let font = weight == .regular ? regular : thin,
      let scalar = Unicode.Scalar(icon.codepoint)
    else { return nil }
    let units = Array(String(scalar).utf16)
    var glyphs = [CGGlyph](repeating: 0, count: units.count)
    guard CTFontGetGlyphsForCharacters(font, units, &glyphs, units.count),
      let outline = CTFontCreatePathForGlyph(font, glyphs[0], nil)
    else { return nil }
    let ascent = CTFontGetAscent(font)
    return Glyph(
      outline: outline,
      ascent: ascent,
      lineHeight: ascent + CTFontGetDescent(font),
      advance: CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, nil, 1)
    )
  }
}
