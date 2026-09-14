#if DEBUG
import SwiftUI
import WidgetKit

/// 開發用：以 `TAT_WIDGET_PREVIEW=1` 啟動時，把小工具每一種尺寸在幾個時間點畫成 PNG，放在 Documents/widget-preview/。
/// 模擬器建置沒有 App Group，小工具本身拿不到課表，版面在這裡看。畫的是最新學期那一張。
enum WidgetPreview {
  @MainActor
  static func renderIfRequested(_ app: AppEnvironment) async {
    guard ProcessInfo.processInfo.environment["TAT_WIDGET_PREVIEW"] == "1",
      let table = await app.widgets.snapshot(language: app.language ?? .system)?.tables.first,
      let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
        .appendingPathComponent("widget-preview")
    else { return }
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let families: [(String, WidgetFamily, CGSize, CGFloat)] = [
      ("small", .systemSmall, CGSize(width: 170, height: 170), 16),
      ("medium", .systemMedium, CGSize(width: 364, height: 170), 16),
      ("large", .systemLarge, CGSize(width: 364, height: 382), 16),
      ("circular", .accessoryCircular, CGSize(width: 76, height: 76), 0),
      ("rectangular", .accessoryRectangular, CGSize(width: 172, height: 76), 0),
      ("inline", .accessoryInline, CGSize(width: 257, height: 26), 0),
    ]
    for (label, date) in moments(table) {
      for scheme in [ColorScheme.light, .dark] {
        for (name, family, size, margin) in families {
          let view = TimetableWidgetContent(
            moment: TimetableMoment(date: date, table: table), family: family,
            margins: EdgeInsets(top: margin, leading: margin, bottom: margin, trailing: margin)
          )
          .frame(width: size.width, height: size.height)
          .background(Color(.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: margin > 0 ? 22 : 0, style: .continuous))
          .environment(\.colorScheme, scheme)
          let renderer = ImageRenderer(content: view)
          renderer.scale = 3
          let file = folder.appendingPathComponent("\(label)-\(scheme == .dark ? "dark" : "light")-\(name).png")
          try? renderer.uiImage?.pngData()?.write(to: file)
        }
      }
    }
  }

  /// 現在、第一堂課上課中、那天最後一堂下課之後。
  private static func moments(_ table: TimetableSnapshot.Table) -> [(String, Date)] {
    var result = [("now", Date.now)]
    guard let first = table.lessons.first else { return result }
    var components = DateComponents()
    components.weekday = first.weekday % 7 + 1
    guard let day = Calendar.current.nextDate(after: .now, matching: components, matchingPolicy: .nextTime)
    else { return result }
    let last = table.lessons.filter { $0.weekday == first.weekday }.map(\.end).max() ?? first.end
    result.append(("inclass", day.addingTimeInterval(TimeInterval((first.start + 20) * 60))))
    result.append(("evening", day.addingTimeInterval(TimeInterval((last + 30) * 60))))
    return result
  }
}
#endif
