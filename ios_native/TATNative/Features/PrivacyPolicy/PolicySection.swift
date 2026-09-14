import Foundation

/// 切法與 Flutter 版 `PolicySection.parse` 一致，包含丟掉 `## ` 大標那一條。
struct PolicySection: Identifiable {
  let id = UUID()
  let title: String?
  let body: String

  static func parse(_ markdown: String) -> [PolicySection] {
    var sections: [PolicySection] = []
    var buffer: [String] = []
    var title: String?

    func flush() {
      let body = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      if title != nil || !body.isEmpty {
        sections.append(PolicySection(title: title, body: body))
      }
      buffer.removeAll()
    }

    for line in markdown.components(separatedBy: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("### ") {
        flush()
        title = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        continue
      }
      if trimmed.hasPrefix("## ") {
        flush()
        title = nil
        continue
      }
      buffer.append(line)
    }
    flush()
    return sections
  }
}
