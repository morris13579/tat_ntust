import Foundation
import Observation

@MainActor
@Observable
final class CalendarModel {
  /// 「2026-09-13」→ 學校行事曆上那一天的事。
  private(set) var schoolDays: [String: [String]] = [:]
  /// nil 代表待辦還在載入。
  private(set) var upcoming: UpcomingEvents?
  var selectedDate = Calendar.current.startOfDay(for: .now)
  private(set) var isBusy = false

  let client: CalendarClient
  private var started = false

  init(client: CalendarClient) {
    self.client = client
  }

  /// 待辦與 .ics 並行：Moodle 慢或失敗都不該擋住月曆，進頁時的待辦是背景載入。
  func start() async {
    guard !started else { return }
    started = true
    async let events: Void = loadUpcoming(refresh: false)
    await loadSchool(refresh: false)
    await events
  }

  /// 依序跑：重新下載 .ics 會問學期，待辦可能開登入頁，兩個畫面才不會疊在一起。
  func refresh() async {
    isBusy = true
    defer { isBusy = false }
    await loadSchool(refresh: true)
    await reloadUpcoming()
  }

  func reloadUpcoming() async {
    upcoming = nil
    await loadUpcoming(refresh: true)
  }

  func schoolEvents(on date: Date) -> [String] {
    schoolDays[CalendarKey.string(for: date)] ?? []
  }

  var deadlineDays: Set<String> {
    Set(
      (upcoming?.groups ?? []).flatMap(\.events).map {
        CalendarKey.string(for: Date(milliseconds: $0.due))
      })
  }

  private func loadSchool(refresh: Bool) async {
    guard let days = try? await client.schoolCalendar(refresh: refresh) else { return }
    schoolDays = Dictionary(days.map { ($0.date, $0.events) }, uniquingKeysWith: { first, _ in first })
  }

  private func loadUpcoming(refresh: Bool) async {
    let result = try? await client.upcoming(refresh: refresh)
    upcoming = result ?? UpcomingEvents(groups: [], error: L10n.unknownError, signedIn: true)
  }
}

/// 月曆格子與清單對日期用的鍵，「2026-09-13」。.ics 是只有日期的那一天，待辦是本地時間的那一天。
enum CalendarKey {
  static func string(for date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return string(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
  }

  static func string(year: Int, month: Int, day: Int) -> String {
    String(format: "%04d-%02d-%02d", year, month, day)
  }

  static func components(_ key: String) -> DateComponents? {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return DateComponents(calendar: Calendar(identifier: .gregorian), year: parts[0], month: parts[1], day: parts[2])
  }
}

extension Date {
  init(milliseconds: Int64) {
    self.init(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
  }
}
