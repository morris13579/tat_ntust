import Foundation

/// 小工具畫的課表。App 寫、小工具 extension 讀：extension 裡沒有 Flutter 引擎，要的東西在 App 回到背景前先寫好。
/// 有哪幾張、連堂怎麼併是 Dart 的判斷（`WidgetTimetable`），這裡照抄下來。
struct TimetableSnapshot: Codable, Equatable {
  struct Day: Codable, Equatable {
    /// 1 是週一，7 是週日。
    let weekday: Int
    let label: String
  }

  struct Section: Codable, Equatable {
    let index: Int
    let label: String
    /// 當天 0 點起算的分鐘數。
    let start: Int
    let end: Int
  }

  struct Lesson: Codable, Hashable {
    let weekday: Int
    let firstSection: Int
    let lastSection: Int
    let start: Int
    let end: Int
    let name: String
    let classroom: String?
    let order: Int
  }

  struct Table: Codable, Equatable {
    /// 「115-1」。
    let semester: String
    let courseCount: Int
    let credits: Int
    let days: [Day]
    let sections: [Section]
    let lessons: [Lesson]
  }

  /// 介面語言的 lproj，跟著核心的設定。
  let language: String
  /// 自己的課表，學期新的在前。
  let tables: [Table]

  /// 小工具設定裡選的學期；沒選、或那一學期的課表已經刪掉時用最新的。
  func table(for semester: String?) -> Table? {
    tables.first { $0.semester == semester } ?? tables.first
  }
}

extension TimetableSnapshot {
  /// 小工具的字串跟著快照記的語言；還沒有快照時跟系統，和 App 第一次啟動的判斷相同。
  static func useLanguage(of snapshot: TimetableSnapshot?) {
    let lproj = snapshot?.language ?? systemLanguage
    L10n.use(lproj: lproj, locale: lproj == "en" ? "en" : "zh_Hant_TW")
  }

  private static var systemLanguage: String {
    guard let first = Locale.preferredLanguages.first,
      Locale(identifier: first).language.languageCode == .chinese
    else { return "en" }
    return "zh-Hant"
  }
}

/// App Group 裡的那一份。
enum TimetableSnapshotStore {
  static let appGroup = "group.club.ntust.tat.72QP2FGS73"

  private static var url: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appendingPathComponent("timetable.json")
  }

  static func read() -> TimetableSnapshot? {
    guard let url, let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(TimetableSnapshot.self, from: data)
  }

  /// 內容有變才寫，回傳有沒有寫。拿不到 App Group（沒有 entitlements 的建置）時什麼都不做。
  @discardableResult
  static func write(_ snapshot: TimetableSnapshot?) -> Bool {
    guard let url, snapshot != read() else { return false }
    guard let snapshot else {
      try? FileManager.default.removeItem(at: url)
      return true
    }
    guard let data = try? JSONEncoder().encode(snapshot) else { return false }
    return (try? data.write(to: url, options: .atomic)) != nil
  }
}
