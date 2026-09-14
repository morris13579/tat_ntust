import UIKit
import WidgetKit

/// 把課表寫給小工具。extension 裡跑不了核心，所以在小工具要被看到之前（App 回到背景）、啟動與登出時各寫一次；
/// 內容沒變就不叫小工具重排，省下系統給的重新整理額度。
@MainActor
final class WidgetSync {
  private let client: WidgetClient

  init(client: WidgetClient) {
    self.client = client
  }

  func refresh(language: AppLanguage) {
    let task = UIApplication.shared.beginBackgroundTask(withName: "timetable-widget")
    Task {
      defer { UIApplication.shared.endBackgroundTask(task) }
      let tables: [WidgetTable]
      do {
        tables = try await client.timetables()
      } catch {
        // 核心沒回答就留著上一份，不要把小工具清空。
        return
      }
      let snapshot = tables.isEmpty ? nil : TimetableSnapshot(tables, language: language.lproj)
      if TimetableSnapshotStore.write(snapshot) {
        WidgetCenter.shared.reloadAllTimelines()
      }
    }
  }

  #if DEBUG
  /// Debug 預覽用：現在的課表換成小工具的格式，不寫檔。
  func snapshot(language: AppLanguage) async -> TimetableSnapshot? {
    guard let tables = try? await client.timetables(), !tables.isEmpty else { return nil }
    return TimetableSnapshot(tables, language: language.lproj)
  }
  #endif
}

extension TimetableSnapshot {
  init(_ tables: [WidgetTable], language: String) {
    self.init(
      language: language,
      tables: tables.map { table in
        Table(
          semester: table.semester,
          courseCount: Int(table.courseCount),
          credits: Int(table.credits),
          days: table.days.map { Day(weekday: Int($0.weekday), label: $0.label) },
          sections: table.sections.map {
            Section(index: Int($0.index), label: $0.label, start: Int($0.start), end: Int($0.end))
          },
          lessons: table.lessons.map {
            Lesson(
              weekday: Int($0.weekday), firstSection: Int($0.firstSection), lastSection: Int($0.lastSection),
              start: Int($0.start), end: Int($0.end), name: $0.name, classroom: $0.classroom, order: Int($0.order))
          })
      })
  }
}
