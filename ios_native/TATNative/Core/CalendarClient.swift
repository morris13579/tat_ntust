import Flutter

/// 行事曆頁的核心呼叫。
@MainActor
final class CalendarClient {
  private let api: TatCalendarApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatCalendarApi(binaryMessenger: messenger)
  }

  func schoolCalendar(refresh: Bool) async throws -> [CalendarDay] {
    try await pigeonCall { api.schoolCalendar(refresh: refresh, completion: $0) }
  }

  func upcoming(refresh: Bool) async throws -> UpcomingEvents {
    try await pigeonCall { api.upcoming(refresh: refresh, completion: $0) }
  }

  func eventLink(id: Int64) async throws -> WebLink? {
    try await pigeonCall { api.eventLink(eventId: id, completion: $0) }
  }

  func eventTarget(id: Int64) async throws -> ModuleTarget? {
    try await pigeonCall { api.eventTarget(eventId: id, completion: $0) }
  }

  func isAutologinScript(_ url: URL) async -> Bool {
    (try? await pigeonCall { api.isAutologinScript(url: url.absoluteString, completion: $0) }) ?? false
  }
}
