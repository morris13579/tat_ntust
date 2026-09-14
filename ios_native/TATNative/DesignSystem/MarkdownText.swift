import SwiftUI

/// TAT 公告的 Markdown，畫 `flutter_markdown` 在公告上會用到的那幾樣：段落、清單、標題、分隔線與行內樣式。
/// 連結交給環境的 openURL。
struct MarkdownText: View {
  let markdown: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(Array(MarkdownBlock.parse(markdown).enumerated()), id: \.offset) { _, block in
        switch block {
        case .heading(let text):
          Text(Self.inline(text)).font(.headline)
        case .item(let marker, let text):
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: marker).monospacedDigit()
            Text(Self.inline(text))
          }
        case .paragraph(let text):
          Text(Self.inline(text))
        case .rule:
          Divider()
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private static func inline(_ text: String) -> AttributedString {
    (try? AttributedString(
      markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
      ?? AttributedString(text)
  }
}

enum MarkdownBlock: Equatable {
  case heading(String)
  case item(marker: String, text: String)
  case paragraph(String)
  case rule

  /// 連續的一般行併成一段，空行分段，和 Markdown 的軟換行一樣。
  static func parse(_ markdown: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    var paragraph: [String] = []
    func flush() {
      guard !paragraph.isEmpty else { return }
      blocks.append(.paragraph(paragraph.joined(separator: " ")))
      paragraph = []
    }
    for raw in markdown.components(separatedBy: .newlines) {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.isEmpty {
        flush()
      } else if line.count >= 3, let first = line.first, "-*_".contains(first), line.allSatisfy({ $0 == first }) {
        flush()
        blocks.append(.rule)
      } else if line.hasPrefix("#"), line.drop(while: { $0 == "#" }).first == " " {
        flush()
        blocks.append(.heading(String(line.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)))
      } else if let first = line.first, "-*+".contains(first), line.dropFirst().first == " " {
        flush()
        blocks.append(.item(marker: "•", text: String(line.dropFirst(2))))
      } else if case let digits = line.prefix(while: \.isNumber), !digits.isEmpty,
        line.dropFirst(digits.count).hasPrefix(". ")
      {
        flush()
        blocks.append(.item(marker: "\(digits).", text: String(line.dropFirst(digits.count + 2))))
      } else {
        paragraph.append(line)
      }
    }
    flush()
    return blocks
  }
}
