import SwiftUI
import WidgetKit

/// 小工具各尺寸的畫面。App 的 Debug 預覽也用這一套，所以尺寸與內距由呼叫端傳進來，不讀 WidgetKit 的環境值。
struct TimetableWidgetContent: View {
  let moment: TimetableMoment
  let family: WidgetFamily
  /// 系統給小工具的內距。大尺寸的格線同課表頁貼齊邊緣，只有上面那一列加內距；小、中尺寸整個加在外面。
  let margins: EdgeInsets

  var body: some View {
    Group {
      if let table = moment.table, let focus = TimetableFocus(moment) {
        switch family {
        case .systemSmall: TimetableSmallView(moment: moment, focus: focus).padding(margins)
        case .systemMedium: TimetableMediumView(moment: moment).padding(margins)
        case .accessoryCircular: TimetableCircularView(moment: moment)
        case .accessoryRectangular: TimetableRectangularView(focus: focus)
        case .accessoryInline: TimetableInlineView(moment: moment)
        default: TimetableLargeView(moment: moment, table: table, margins: margins)
        }
      } else {
        TimetablePlaceholder(family: family, margins: margins)
      }
    }
    .environment(\.locale, L10n.locale)
  }
}

enum TimetableText {
  static func time(_ minutes: Int) -> String {
    String(format: "%02d:%02d", minutes / 60, minutes % 60)
  }

  static func range(_ lesson: TimetableSnapshot.Lesson) -> String {
    "\(time(lesson.start))–\(time(lesson.end))"
  }

  static func weekday(_ weekday: Int) -> String {
    let names = [L10n.Monday, L10n.Tuesday, L10n.Wednesday, L10n.Thursday, L10n.Friday, L10n.Saturday, L10n.Sunday]
    return L10n.widgetWeekday(names[(weekday + 6) % 7])
  }

  /// 下一堂在哪一天：今天是「下一堂」，明天是「明天」，再之後是星期幾。
  static func when(_ upcoming: TimetableMoment.Upcoming) -> String {
    upcoming.dayOffset == 0 ? L10n.widgetNextClass : day(offset: upcoming.dayOffset, weekday: upcoming.lesson.weekday)
  }

  static func day(offset: Int, weekday: Int) -> String {
    switch offset {
    case 0: L10n.widgetToday
    case 1: L10n.widgetTomorrow
    default: self.weekday(weekday)
    }
  }
}

/// 小工具最想讓人看到的那一堂：正在上的，不然就是下一堂。
struct TimetableFocus {
  let lesson: TimetableSnapshot.Lesson
  /// 「上課中」「下一堂」「明天」「週三」。
  let status: String
  /// 上課中是「18:20 下課」，其餘是「13:20–15:10」。
  let detail: String

  init?(_ moment: TimetableMoment) {
    if let lesson = moment.current {
      self.lesson = lesson
      status = L10n.widgetInClass
      detail = L10n.widgetEndsAt(TimetableText.time(lesson.end))
    } else if let upcoming = moment.upcoming {
      lesson = upcoming.lesson
      status = TimetableText.when(upcoming)
      detail = TimetableText.range(upcoming.lesson)
    } else {
      return nil
    }
  }
}

/// 課的底色：全彩時和課表格子同色；染色模式下改用系統的填色，免得整塊變成一片灰。
private struct TimetableLessonFill: ShapeStyle {
  let order: Int

  func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
    environment.widgetRenderingMode == .fullColor
      ? AnyShapeStyle(CoursePalette.color(for: Int64(order)))
      : AnyShapeStyle(.fill.tertiary)
  }
}

/// 課的強調色（色條、狀態字）：淺色底用同色相壓深的顏色，深色底用格子的淺色，兩邊都看得清楚；染色模式下跟著系統。
private struct TimetableLessonAccent: ShapeStyle {
  let order: Int

  func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
    guard environment.widgetRenderingMode == .fullColor else { return AnyShapeStyle(.primary) }
    let order = Int64(order)
    return environment.colorScheme == .dark
      ? AnyShapeStyle(CoursePalette.color(for: order))
      : AnyShapeStyle(CoursePalette.bandForeground(for: order))
  }
}

private struct TimetableSmallView: View {
  let moment: TimetableMoment
  let focus: TimetableFocus

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(focus.status)
        .font(.caption.weight(.semibold))
        .foregroundStyle(TimetableLessonAccent(order: focus.lesson.order))
        .lineLimit(1)
        .widgetAccentable()
      Spacer(minLength: 6)
      TimetableLessonSummary(lesson: focus.lesson, detail: focus.detail)
      Spacer(minLength: 6)
      if let next = moment.following(focus.lesson) {
        Text(verbatim: "\(L10n.widgetThen) \(TimetableText.time(next.start)) \(next.name)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// 色條加上課名、時間與教室。
private struct TimetableLessonSummary: View {
  let lesson: TimetableSnapshot.Lesson
  let detail: String

  var body: some View {
    HStack(spacing: 8) {
      Capsule()
        .fill(TimetableLessonAccent(order: lesson.order))
        .frame(width: 4)
      VStack(alignment: .leading, spacing: 2) {
        Text(lesson.name)
          .font(.title3.weight(.semibold))
          .lineLimit(2)
          .minimumScaleFactor(0.8)
        Text(detail)
          .font(.footnote.monospacedDigit())
          .foregroundStyle(.secondary)
          .lineLimit(1)
        if let room = lesson.classroom {
          Text(room)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct TimetableMediumView: View {
  let moment: TimetableMoment

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 0) {
        Text(TimetableText.weekday(moment.weekday))
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(verbatim: String(Calendar.current.component(.day, from: moment.date)))
          .font(.largeTitle.weight(.semibold))
        Spacer(minLength: 4)
        Text(summary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .frame(width: 64, alignment: .leading)

      VStack(alignment: .leading, spacing: 8) {
        ForEach(today, id: \.self) { lesson in
          TimetableLessonRow(lesson: lesson, isCurrent: lesson == moment.current)
        }
        if let later {
          Text(later.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          ForEach(later.lessons, id: \.self) { lesson in
            TimetableLessonRow(lesson: lesson, isCurrent: false)
          }
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// 今天還沒下課的，最多三堂。
  private var today: [TimetableSnapshot.Lesson] { Array(moment.remaining.prefix(3)) }

  /// 今天剩不到兩堂時，接著列下一個有課的日子，放得下幾堂列幾堂。
  private var later: (title: String, lessons: [TimetableSnapshot.Lesson])? {
    let room = 2 - today.count
    guard room > 0, let next = moment.nextLessonDay, let first = next.lessons.first else { return nil }
    return (TimetableText.day(offset: next.dayOffset, weekday: first.weekday), Array(next.lessons.prefix(room)))
  }

  private var summary: String {
    if moment.current != nil { return L10n.widgetInClass }
    let remaining = moment.remaining.count
    if remaining > 0 { return L10n.widgetClassesLeft(String(remaining)) }
    return moment.today.isEmpty ? L10n.widgetNoClassToday : L10n.widgetDoneToday
  }
}

private struct TimetableLessonRow: View {
  let lesson: TimetableSnapshot.Lesson
  let isCurrent: Bool

  var body: some View {
    HStack(spacing: 8) {
      Capsule()
        .fill(TimetableLessonAccent(order: lesson.order))
        .frame(width: 4)
      VStack(alignment: .leading, spacing: 1) {
        Text(lesson.name)
          .font(.subheadline.weight(isCurrent ? .semibold : .regular))
          .lineLimit(1)
        Text(verbatim: [TimetableText.range(lesson), lesson.classroom].compactMap { $0 }.joined(separator: " · "))
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// 同課表頁：上面一列是日期、門數與學分、學期，下面是整週的格線。
private struct TimetableLargeView: View {
  let moment: TimetableMoment
  let table: TimetableSnapshot.Table
  let margins: EdgeInsets

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        VStack(alignment: .leading, spacing: 2) {
          Text(moment.date, format: .dateTime.month().day().weekday(.wide))
            .font(.body.weight(.medium))
          Text(verbatim: "\(L10n.courseCount(String(table.courseCount))) · \(L10n.creditCount(String(table.credits)))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        Spacer(minLength: 0)
        Text(table.semester)
          .font(.subheadline.weight(.medium).monospacedDigit())
      }
      .padding(EdgeInsets(top: margins.top, leading: margins.leading, bottom: 4, trailing: margins.trailing))
      TimetableWeekGrid(moment: moment, table: table)
    }
  }
}

/// 整週的格線，畫法同課表頁的 `CourseGridContent`：一節一列、單雙列交錯底色，每一格一塊淺色圓角、課名置中。
private struct TimetableWeekGrid: View {
  let moment: TimetableMoment
  let table: TimetableSnapshot.Table
  @Environment(\.widgetRenderingMode) private var renderingMode

  private static let headerHeight: CGFloat = 22
  private static let sectionWidth: CGFloat = 22
  /// 最右邊一欄離小工具的圓角遠一點。
  private static let trailingInset: CGFloat = 4

  private struct Slot: Hashable {
    let weekday: Int
    let section: Int
  }

  var body: some View {
    let cells = slots
    VStack(spacing: 0) {
      header
      ForEach(Array(sections.enumerated()), id: \.element.index) { offset, section in
        row(section, cells: cells)
          .frame(maxHeight: .infinity)
          .background(stripe(offset))
      }
    }
  }

  /// 同課表頁一節一列；有晚上的課、節數多到擠不下時，頭尾整列沒課的節不畫。
  private var sections: [TimetableSnapshot.Section] {
    guard table.sections.count > 10 else { return table.sections }
    let used = Set(table.lessons.flatMap { $0.firstSection...$0.lastSection })
    guard let first = table.sections.firstIndex(where: { used.contains($0.index) }),
      let last = table.sections.lastIndex(where: { used.contains($0.index) })
    else { return table.sections }
    return Array(table.sections[first...last])
  }

  /// 小工具的資料把連堂併成一段，這裡照課表頁拆回一節一格。
  private var slots: [Slot: TimetableSnapshot.Lesson] {
    var result: [Slot: TimetableSnapshot.Lesson] = [:]
    for lesson in table.lessons {
      for section in lesson.firstSection...lesson.lastSection {
        result[Slot(weekday: lesson.weekday, section: section)] = lesson
      }
    }
    return result
  }

  /// 染色模式下整列墊不透明的底色會染成一整片，只留淡淡的雙數列。
  private func stripe(_ offset: Int) -> Color {
    let even = offset.isMultiple(of: 2)
    guard renderingMode == .fullColor else { return even ? .clear : Color.primary.opacity(0.06) }
    return even ? Color(.systemBackground) : Color(.secondarySystemBackground)
  }

  private var header: some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: Self.sectionWidth)
      ForEach(table.days, id: \.weekday) { day in
        let isToday = day.weekday == moment.weekday
        Text(day.label)
          .font(.caption.weight(isToday ? .semibold : .regular))
          .foregroundStyle(isToday ? Color.primary : Color.secondary)
          .frame(maxWidth: .infinity)
      }
      Color.clear.frame(width: Self.trailingInset)
    }
    .frame(height: Self.headerHeight)
  }

  private func row(_ section: TimetableSnapshot.Section, cells: [Slot: TimetableSnapshot.Lesson]) -> some View {
    HStack(spacing: 0) {
      Text(section.label)
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: Self.sectionWidth)
      ForEach(table.days, id: \.weekday) { day in
        if let lesson = cells[Slot(weekday: day.weekday, section: section.index)] {
          block(lesson).padding(1.5)
        } else {
          Color.clear.frame(maxWidth: .infinity)
        }
      }
      Color.clear.frame(width: Self.trailingInset)
    }
  }

  private func block(_ lesson: TimetableSnapshot.Lesson) -> some View {
    Text(lesson.name)
      .font(.caption.weight(.medium))
      .foregroundStyle(renderingMode == .fullColor ? CoursePalette.foreground : Color.primary)
      .multilineTextAlignment(.center)
      .lineLimit(2)
      .minimumScaleFactor(0.7)
      .padding(2)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        TimetableLessonFill(order: lesson.order),
        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}

private struct TimetableCircularView: View {
  let moment: TimetableMoment

  var body: some View {
    if let lesson = moment.current, let start = moment.start(of: lesson), let end = moment.end(of: lesson) {
      ProgressView(timerInterval: start...end, countsDown: false) {
        EmptyView()
      } currentValueLabel: {
        Text(TimetableText.time(lesson.end))
          .font(.caption2.monospacedDigit())
      }
      .progressViewStyle(.circular)
      .widgetAccentable()
    } else if let upcoming = moment.upcoming {
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 0) {
          Text(TimetableText.when(upcoming))
            .font(.caption2)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
          Text(TimetableText.time(upcoming.lesson.start))
            .font(.headline.monospacedDigit())
            .minimumScaleFactor(0.6)
            .widgetAccentable()
        }
        .padding(4)
      }
    }
  }
}

private struct TimetableRectangularView: View {
  let focus: TimetableFocus

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(verbatim: "\(focus.status) · \(focus.detail)")
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .widgetAccentable()
      Text(focus.lesson.name)
        .font(.headline)
        .lineLimit(1)
      if let room = focus.lesson.classroom {
        Text(room)
          .font(.caption)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct TimetableInlineView: View {
  let moment: TimetableMoment

  var body: some View {
    Text(text)
  }

  private var text: String {
    if let lesson = moment.current {
      return "\(L10n.widgetEndsAt(TimetableText.time(lesson.end))) \(lesson.name)"
    }
    guard let upcoming = moment.upcoming else { return "" }
    let time = "\(TimetableText.time(upcoming.lesson.start)) \(upcoming.lesson.name)"
    return upcoming.dayOffset == 0 ? time : "\(TimetableText.when(upcoming)) \(time)"
  }
}

private struct TimetablePlaceholder: View {
  let family: WidgetFamily
  let margins: EdgeInsets

  var body: some View {
    switch family {
    case .accessoryInline:
      Text(L10n.widgetOpenApp)
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        LucideImage(Lucide.table, size: 22)
      }
    case .accessoryRectangular:
      Text(L10n.widgetOpenApp)
        .font(.caption)
        .lineLimit(3)
        .frame(maxWidth: .infinity, alignment: .leading)
    default:
      VStack(alignment: .leading, spacing: 8) {
        LucideImage(Lucide.table, size: 26)
          .foregroundStyle(.secondary)
        Text(L10n.widgetOpenApp)
          .font(.subheadline.weight(.medium))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(margins)
    }
  }
}
