import Foundation

/// 某個時間點上小工具要顯示的課：正在上的、下一堂、今天還剩的。只照星期與時間查表。
struct TimetableMoment {
  typealias Lesson = TimetableSnapshot.Lesson

  struct Upcoming {
    let lesson: Lesson
    /// 0 是今天，1 是明天。
    let dayOffset: Int
  }

  let date: Date
  let table: TimetableSnapshot.Table?
  private let calendar: Calendar

  init(date: Date, table: TimetableSnapshot.Table?, calendar: Calendar = .current) {
    self.date = date
    self.table = table
    self.calendar = calendar
  }

  /// 1 是週一，7 是週日。
  var weekday: Int { Self.weekday(of: date, in: calendar) }

  var today: [Lesson] { lessons(on: weekday) }

  var current: Lesson? {
    let now = minutes
    return today.first { $0.start <= now && now < $0.end }
  }

  /// 今天還沒下課的，包含正在上的。
  var remaining: [Lesson] {
    let now = minutes
    return today.filter { $0.end > now }
  }

  /// 還沒開始的下一堂。今天沒有就往後找，最遠到下週同一天。
  var upcoming: Upcoming? {
    let now = minutes
    let startOfToday = calendar.startOfDay(for: date)
    for offset in 0...7 {
      guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
      let candidates = lessons(on: Self.weekday(of: day, in: calendar))
      if let lesson = candidates.first(where: { offset > 0 || $0.start > now }) {
        return Upcoming(lesson: lesson, dayOffset: offset)
      }
    }
    return nil
  }

  /// 明天起下一個有課的日子。
  var nextLessonDay: (dayOffset: Int, lessons: [Lesson])? {
    let startOfToday = calendar.startOfDay(for: date)
    for offset in 1...7 {
      guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
      let found = lessons(on: Self.weekday(of: day, in: calendar))
      if !found.isEmpty { return (offset, found) }
    }
    return nil
  }

  /// 同一天接在這堂之後的下一堂。
  func following(_ lesson: Lesson) -> Lesson? {
    lessons(on: lesson.weekday).first { $0.start >= lesson.end }
  }

  func lessons(on weekday: Int) -> [Lesson] {
    let all: [Lesson] = table?.lessons ?? []
    return all.filter { $0.weekday == weekday }.sorted { $0.start < $1.start }
  }

  /// 今天這堂課開始與下課的時刻。
  func start(of lesson: Lesson) -> Date? { today(at: lesson.start) }

  func end(of lesson: Lesson) -> Date? { today(at: lesson.end) }

  /// 小工具要換畫面的時間點：接下來三天每堂課的上課與下課，以及每天 0 點。
  static func entryDates(
    for table: TimetableSnapshot.Table?, from now: Date, calendar: Calendar = .current
  ) -> [Date] {
    var dates: Set<Date> = [now]
    let startOfToday = calendar.startOfDay(for: now)
    let lessons: [Lesson] = table?.lessons ?? []
    for offset in 0...2 {
      guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
      if offset > 0 { dates.insert(day) }
      let weekday = weekday(of: day, in: calendar)
      for lesson in lessons where lesson.weekday == weekday {
        for minute in [lesson.start, lesson.end] {
          if let date = calendar.date(byAdding: .minute, value: minute, to: day) {
            dates.insert(date)
          }
        }
      }
    }
    return dates.filter { $0 >= now }.sorted()
  }

  private var minutes: Int {
    calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
  }

  private func today(at minute: Int) -> Date? {
    calendar.date(byAdding: .minute, value: minute, to: calendar.startOfDay(for: date))
  }

  /// Calendar 的星期是週日 1、週六 7，這裡換成週一 1、週日 7。
  private static func weekday(of date: Date, in calendar: Calendar) -> Int {
    (calendar.component(.weekday, from: date) + 5) % 7 + 1
  }
}
