import SwiftUI
import UIKit

/// Moodle 給的 HTML（老師回饋這類）轉成純文字加連結，套用系統字型。
struct HTMLText: View {
  let html: String
  @State private var text: AttributedString?

  var body: some View {
    Text(text ?? AttributedString())
      .task(id: html) { text = Self.attributed(html) }
  }

  /// 圖片先拿掉：匯入器遇到遠端圖片會在主執行緒上同步去抓。
  static func attributed(_ html: String) -> AttributedString {
    let stripped = html.replacingOccurrences(of: "<img[^>]*>", with: "", options: .regularExpression)
    guard let data = stripped.data(using: .utf8),
      let imported = try? NSAttributedString(
        data: data,
        options: [
          .documentType: NSAttributedString.DocumentType.html,
          .characterEncoding: String.Encoding.utf8.rawValue,
        ],
        documentAttributes: nil)
    else { return AttributedString(html) }
    var result = (try? AttributedString(imported, including: \.foundation)) ?? AttributedString(imported.string)
    while let last = result.characters.last, last.isWhitespace {
      result.characters.removeLast()
    }
    return result
  }
}
