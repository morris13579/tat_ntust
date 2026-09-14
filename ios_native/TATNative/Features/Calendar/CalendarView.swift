import SwiftUI

/// 行事曆，照 `calendar_page.dart`：月曆與圖例、選到那一天學校行事曆上的事、底下所有課程的待辦。
struct CalendarView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: CalendarModel
  @State private var page: WebPage?
  @State private var opening: Int64?
  @State private var module: ModuleRoute?

  init(model: CalendarModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          calendarCard
          VStack(alignment: .leading, spacing: 0) {
            daySection
            upcomingSection
          }
          .padding(EdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16))
        }
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle(L10n.calendar)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            Task { await model.refresh() }
          } label: {
            LucideImage(Lucide.refreshCw, size: 20)
          }
          .accessibilityLabel(L10n.update)
          .disabled(model.isBusy)
          .toolbarButtonTint()
        }
      }
      .browserSheet(item: $page) { await model.client.isAutologinScript($0) }
      .navigationDestination(item: $module) { route in
        MoodleDestinationView(destination: route.destination, course: route.course)
      }
    }
    .task { await model.start() }
  }

  private var calendarCard: some View {
    VStack(alignment: .leading, spacing: 4) {
      MonthCalendarView(
        schoolDays: Set(model.schoolDays.keys), deadlineDays: model.deadlineDays,
        selection: $model.selectedDate)
      // 兩種點沒有圖例就只是兩個不明所以的顏色。
      HStack(spacing: 16) {
        legend(Color.tatBrand, L10n.calendarSourceSchool)
        legend(Color(.systemOrange), L10n.calendarSourceDeadline)
      }
      .padding(.horizontal, 12)
    }
    .padding(.bottom, 12)
    .background(Color(.secondarySystemGroupedBackground))
  }

  private func legend(_ color: Color, _ label: String) -> some View {
    HStack(spacing: 7) {
      Circle().fill(color).frame(width: 6, height: 6)
      Text(label).font(.footnote).foregroundStyle(.secondary)
    }
  }

  /// 選到的那一天學校行事曆上寫了什麼。Moodle 的截止事項在下面的待辦，不在這裡重複。
  @ViewBuilder private var daySection: some View {
    let events = model.schoolEvents(on: model.selectedDate)
    if !events.isEmpty {
      SectionHeader(title: dayTitle, count: events.count, first: true)
      VStack(spacing: 2) {
        ForEach(Array(events.enumerated()), id: \.offset) { index, event in
          CalendarEventRow(
            icon: Lucide.building2, iconColor: Color.tatBrand, title: event,
            subtitle: L10n.calendarSourceSchool, index: index, count: events.count)
        }
      }
    }
  }

  private var dayTitle: String {
    let formatter = DateFormatter()
    formatter.locale = L10n.locale
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    let title = formatter.string(from: model.selectedDate)
    return Calendar.current.isDateInToday(model.selectedDate) ? "\(title) · \(L10n.deadlineToday)" : title
  }

  @ViewBuilder private var upcomingSection: some View {
    let first = model.schoolEvents(on: model.selectedDate).isEmpty
    if let upcoming = model.upcoming {
      if let error = upcoming.error, upcoming.groups.isEmpty {
        SectionHeader(title: L10n.upcomingEvents, first: first)
        InlineErrorView(message: error, signedIn: upcoming.signedIn, presenter: app.presenter) {
          await model.reloadUpcoming()
        }
      } else if upcoming.groups.isEmpty {
        SectionHeader(title: L10n.upcomingEvents, first: first)
        SectionEmptyState(message: L10n.upcomingEventsEmpty, icon: Lucide.calendar)
      } else {
        if let notice = upcoming.notice {
          NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh) {
            Task { await model.reloadUpcoming() }
          }
          .clipShape(ListGroupShape.card)
          .padding(.top, first ? 8 : 20)
        }
        ForEach(Array(UpcomingSection.split(upcoming.groups).enumerated()), id: \.offset) {
          index, section in
          SectionHeader(
            title: "\(L10n.upcomingEvents) · \(section.label)", count: section.events.count,
            first: first && index == 0 && upcoming.notice == nil)
          VStack(spacing: 2) {
            ForEach(Array(section.events.enumerated()), id: \.element.id) { row, event in
              Button {
                Task { await open(event) }
              } label: {
                CalendarEventRow(
                  icon: UpcomingSection.icon(event.module), iconColor: UpcomingSection.color(section.kind),
                  title: event.title, subtitle: UpcomingSection.subtitle(event, section.kind),
                  subtitleColor: section.kind == .overdue ? Color(.systemRed) : nil,
                  index: row, count: section.events.count, busy: opening == event.id)
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    } else {
      SectionHeader(title: L10n.upcomingEvents, first: first)
      ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
    }
  }

  /// 作業、測驗、討論區在 App 內開，照 `RouteUtils.tryOpenUpcomingEvent`；其餘先換成免登入網址再開網頁。
  private func open(_ event: UpcomingEvent) async {
    guard opening == nil else { return }
    opening = event.id
    defer { opening = nil }
    if let target = try? await model.client.eventTarget(id: event.id),
      let destination = CourseMoodleModel.Destination.of(target.module)
    {
      module = ModuleRoute(
        course: CourseRef(courseId: target.courseId, name: target.courseName, semester: ""), destination: destination)
      return
    }
    guard let link = try? await model.client.eventLink(id: event.id), let url = URL(string: link.url)
    else { return }
    page = WebPage(title: event.title, url: url, fallbackURL: link.fallbackUrl.flatMap(URL.init(string:)))
  }
}

/// 待辦畫面上的一組。「之後」再按月份切開，不然三個月的截止日會全部擠在同一組。
private struct UpcomingSection {
  let label: String
  let kind: DeadlineKind
  let events: [UpcomingEvent]

  static func split(_ groups: [UpcomingGroup], now: Date = .now) -> [UpcomingSection] {
    var sections: [UpcomingSection] = []
    for group in groups {
      guard group.kind == .later else {
        sections.append(UpcomingSection(label: label(group.kind), kind: group.kind, events: group.events))
        continue
      }
      // Dart 已經照時間排好，同一個月份的一定相連。
      var month: [UpcomingEvent] = []
      for event in group.events {
        if let last = month.last, !Calendar.current.isDate(
          Date(milliseconds: last.due), equalTo: Date(milliseconds: event.due), toGranularity: .month)
        {
          sections.append(UpcomingSection(label: monthLabel(month[0], now: now), kind: .later, events: month))
          month = []
        }
        month.append(event)
      }
      if !month.isEmpty {
        sections.append(UpcomingSection(label: monthLabel(month[0], now: now), kind: .later, events: month))
      }
    }
    return sections
  }

  static func label(_ kind: DeadlineKind) -> String {
    switch kind {
    case .overdue: L10n.deadlineOverdue
    case .today: L10n.deadlineToday
    case .thisWeek: L10n.deadlineThisWeek
    case .later: L10n.deadlineLater
    }
  }

  /// 本月剩下的那幾天寫「9月下半」，之後的月份只寫月份；跨年補年份。
  static func monthLabel(_ event: UpcomingEvent, now: Date) -> String {
    let due = Date(milliseconds: event.due)
    let formatter = DateFormatter()
    formatter.locale = L10n.locale
    let sameYear = Calendar.current.isDate(due, equalTo: now, toGranularity: .year)
    formatter.setLocalizedDateFormatFromTemplate(sameYear ? "MMM" : "yMMM")
    let month = formatter.string(from: due)
    return Calendar.current.isDate(due, equalTo: now, toGranularity: .month)
      ? L10n.deadlineRestOfMonth(month) : month
  }

  /// 「課名 · 9月11日 15:30 · 剩 4 天」。剩餘時間只有今天與本週那兩組才寫，跨年才補年份。
  static func subtitle(_ event: UpcomingEvent, _ kind: DeadlineKind, now: Date = .now) -> String {
    let due = Date(milliseconds: event.due)
    var parts: [String] = []
    if let course = event.course, !course.trimmingCharacters(in: .whitespaces).isEmpty {
      parts.append(course)
    }
    let formatter = DateFormatter()
    formatter.locale = L10n.locale
    let sameYear = Calendar.current.isDate(due, equalTo: now, toGranularity: .year)
    formatter.setLocalizedDateFormatFromTemplate(sameYear ? "MMMdHHmm" : "yMMMdHHmm")
    parts.append(formatter.string(from: due))
    if kind == .today || kind == .thisWeek, let remaining = remaining(due, now: now) {
      parts.append(remaining)
    }
    return parts.joined(separator: " · ")
  }

  private static func remaining(_ due: Date, now: Date) -> String? {
    let left = due.timeIntervalSince(now)
    guard left >= 0 else { return nil }
    if left < 3600 { return L10n.assignDueSoon }
    if left < 86400 { return L10n.deadlineRemainingHours(String(Int(left / 3600))) }
    return L10n.deadlineRemainingDays(String(Int(left / 86400)))
  }

  static func icon(_ module: String?) -> LucideIcon {
    switch module {
    case "assign": Lucide.clipboardList
    case "quiz": Lucide.fileQuestion
    case "forum": Lucide.messagesSquare
    case "lesson", "scorm": Lucide.bookOpen
    case "choice", "feedback", "survey": Lucide.vote
    default: Lucide.calendarDays
    }
  }

  /// 圖示顏色就是急迫程度：逾期紅、今天與本週橘、更遠的淡下來。
  static func color(_ kind: DeadlineKind) -> Color {
    switch kind {
    case .overdue: Color(.systemRed)
    case .today, .thisWeek: Color(.systemOrange)
    case .later: Color.secondary
    }
  }
}

/// 行事曆清單的一列：圖示、標題，底下一行「來源 · 時間 · 剩餘」，照 `calendar_event_row.dart`。
private struct CalendarEventRow: View {
  let icon: LucideIcon
  let iconColor: Color
  let title: String
  var subtitle: String?
  var subtitleColor: Color?
  let index: Int
  let count: Int
  var busy = false

  var body: some View {
    HStack(alignment: .top, spacing: 13) {
      ZStack {
        if busy {
          ProgressView().controlSize(.small)
        } else {
          LucideImage(icon, size: 20).foregroundStyle(iconColor)
        }
      }
      .frame(width: 22, height: 22)
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .foregroundStyle(Color.primary)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(subtitleColor ?? Color.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 13)
    .background(
      Color(.secondarySystemGroupedBackground), in: GroupedRowShape(index: index, count: count))
    .contentShape(Rectangle())
  }
}
