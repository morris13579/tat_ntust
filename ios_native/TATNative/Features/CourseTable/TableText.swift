import Foundation

/// 課表清單上那幾種摘要字串，切換器與管理頁共用同一份。
enum TableText {
  /// 「B11230223 115-1」，同 Flutter 版的 `favoriteLabelOf`。
  static func label(_ table: MyTable) -> String {
    "\(table.studentId) \(table.semester)"
  }

  /// 「6 門課 · 14 學分」。
  static func summary(courses: Int64, credits: Int64) -> String {
    "\(L10n.courseCount(String(courses))) · \(L10n.creditCount(String(credits)))"
  }

  /// 「115-1 · 6 門課 · 9/13 匯入」。
  static func imported(_ table: SharedTableInfo) -> String {
    let formatter = DateFormatter()
    formatter.locale = L10n.locale
    formatter.setLocalizedDateFormatFromTemplate("Md")
    let date = Date(timeIntervalSince1970: TimeInterval(table.savedAt) / 1000)
    return [
      table.semester,
      L10n.courseCount(String(table.courseCount)),
      L10n.importedOn(formatter.string(from: date)),
    ].joined(separator: " · ")
  }
}
