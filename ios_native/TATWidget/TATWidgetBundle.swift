import AppIntents
import SwiftUI
import WidgetKit

/// 課表的桌面與鎖定畫面小工具。這裡沒有 Flutter 引擎，只讀 App 寫進 App Group 的課表（`TimetableSnapshotStore`）。
@main
struct TATWidgetBundle: WidgetBundle {
  init() {
    TimetableSnapshot.useLanguage(of: TimetableSnapshotStore.read())
  }

  var body: some Widget {
    TimetableWidget()
  }
}

struct TimetableWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "timetable", intent: TimetableWidgetIntent.self, provider: TimetableProvider()) {
      entry in
      TimetableEntryView(entry: entry)
    }
    .configurationDisplayName(L10n.titleCourse)
    .description(L10n.widgetDescription)
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge,
      .accessoryCircular, .accessoryRectangular, .accessoryInline,
    ])
    // 大尺寸的格線要貼齊邊緣，內距交給畫面自己決定加在哪裡（`TimetableWidgetContent`）。
    .contentMarginsDisabled()
  }
}

/// 長按小工具、「編輯小工具」裡的設定：看哪一學期。設定畫面的字跟著系統語言，key 是 ARB 產生的 Localizable.strings。
struct TimetableWidgetIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource { "titleCourse" }
  static var description: IntentDescription { "widgetDescription" }

  @Parameter(title: "widgetSemester")
  var semester: TimetableSemester?
}

/// 設定裡可以選的學期：「最新學期」會跟著 App 下載到的新學期換，其餘是 App 下載過的某一學期。
struct TimetableSemester: AppEntity {
  static let latest = "latest"

  let id: String

  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(name: "widgetSemester")
  }

  static var defaultQuery: TimetableSemesterQuery { TimetableSemesterQuery() }

  var displayRepresentation: DisplayRepresentation {
    id == Self.latest ? DisplayRepresentation(title: "widgetLatestSemester") : DisplayRepresentation(title: "\(id)")
  }
}

struct TimetableSemesterQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [TimetableSemester] {
    identifiers.map(TimetableSemester.init(id:))
  }

  func suggestedEntities() async throws -> [TimetableSemester] {
    let semesters = TimetableSnapshotStore.read()?.tables.map(\.semester) ?? []
    return ([TimetableSemester.latest] + semesters).map(TimetableSemester.init(id:))
  }

  func defaultResult() async -> TimetableSemester? {
    TimetableSemester(id: TimetableSemester.latest)
  }
}

struct TimetableEntry: TimelineEntry {
  let date: Date
  let table: TimetableSnapshot.Table?
}

struct TimetableProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> TimetableEntry {
    TimetableEntry(date: .now, table: load(nil))
  }

  func snapshot(for configuration: TimetableWidgetIntent, in context: Context) async -> TimetableEntry {
    TimetableEntry(date: .now, table: load(configuration.semester))
  }

  func timeline(for configuration: TimetableWidgetIntent, in context: Context) async -> Timeline<TimetableEntry> {
    let table = load(configuration.semester)
    let now = Date.now
    let dates = TimetableMoment.entryDates(for: table, from: now)
    // 排好的時間點用完再來要；App 寫了新的課表會自己叫小工具重排。
    let reload = dates.count > 1 ? dates[dates.count - 1] : now.addingTimeInterval(6 * 60 * 60)
    return Timeline(entries: dates.map { TimetableEntry(date: $0, table: table) }, policy: .after(reload))
  }

  private func load(_ semester: TimetableSemester?) -> TimetableSnapshot.Table? {
    let snapshot = TimetableSnapshotStore.read()
    TimetableSnapshot.useLanguage(of: snapshot)
    return snapshot?.table(for: semester?.id)
  }
}

private struct TimetableEntryView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.widgetContentMargins) private var margins
  let entry: TimetableEntry

  var body: some View {
    TimetableWidgetContent(
      moment: TimetableMoment(date: entry.date, table: entry.table), family: family, margins: margins)
      .containerBackground(for: .widget) {
        Color(.systemBackground)
      }
  }
}
