import SwiftUI
import UIKit

/// 月曆，尺寸照 Flutter 版的 `TableCalendar`（星期列 22、每列 46）：系統的 `UICalendarView` 固定很高，會把底下的
/// 待辦擠出畫面。每一天底下的點照 `CalendarDayCell`：品牌色是學校行事曆、橘色是作業截止，兩種都有就並排。
struct MonthCalendarView: View {
  let schoolDays: Set<String>
  let deadlineDays: Set<String>
  @Binding var selection: Date
  @State private var month = MonthCalendarView.startOfMonth(.now)

  private static let rowHeight: CGFloat = 46
  private static let weekdayHeight: CGFloat = 22
  /// 前後各翻得到一年。
  private static let reach = 12

  var body: some View {
    VStack(spacing: 0) {
      header
      weekdays
      days
    }
    .contentShape(Rectangle())
    .simultaneousGesture(
      DragGesture(minimumDistance: 24).onEnded { value in
        guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
        shift(value.translation.width < 0 ? 1 : -1)
      }
    )
    .onAppear { month = Self.startOfMonth(selection) }
    .onChange(of: selection) { _, date in
      let start = Self.startOfMonth(date)
      if start != month { month = start }
    }
  }

  private var header: some View {
    HStack(spacing: 0) {
      Text(Self.monthTitle(month))
        .font(.headline)
        .monospacedDigit()
      Spacer(minLength: 8)
      arrow(Lucide.chevronLeft, L10n.previousMonth, delta: -1)
      arrow(Lucide.chevronRight, L10n.nextMonth, delta: 1)
    }
    .padding(.leading, 12)
    .frame(height: 44)
  }

  private var weekdays: some View {
    HStack(spacing: 0) {
      ForEach(Self.weekdaySymbols(), id: \.self) { symbol in
        Text(symbol)
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
      }
    }
    .frame(height: Self.weekdayHeight)
  }

  private var days: some View {
    let cells = Self.cells(for: month)
    return VStack(spacing: 0) {
      ForEach(0..<(cells.count / 7), id: \.self) { row in
        HStack(spacing: 0) {
          ForEach(0..<7, id: \.self) { column in
            if let date = cells[row * 7 + column] {
              day(date)
            } else {
              Color.clear.frame(maxWidth: .infinity)
            }
          }
        }
        .frame(height: Self.rowHeight)
      }
    }
  }

  private func day(_ date: Date) -> some View {
    let calendar = Self.calendar
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    let key = CalendarKey.string(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    let selected = calendar.isDate(date, inSameDayAs: selection)
    let today = calendar.isDateInToday(date)
    return Button {
      selection = date
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      VStack(spacing: 3) {
        Text(verbatim: "\(parts.day ?? 0)")
          .font(.body.monospacedDigit().weight(today || selected ? .semibold : .regular))
          .foregroundStyle(selected ? Color.white : (today ? Color.tatBrand : Color.primary))
          .frame(width: 34, height: 34)
          .background(selected ? Color.tatBrand : Color.clear, in: Circle())
        HStack(spacing: 3) {
          if schoolDays.contains(key) { dot(Color.tatBrand) }
          if deadlineDays.contains(key) { dot(Color(.systemOrange)) }
        }
        .frame(height: 5)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Self.fullDate(date))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func dot(_ color: Color) -> some View {
    Circle().fill(color).frame(width: 5, height: 5)
  }

  private func arrow(_ icon: LucideIcon, _ label: String, delta: Int) -> some View {
    let enabled = canShift(delta)
    return Button {
      shift(delta)
    } label: {
      LucideImage(icon, size: 20)
        .foregroundStyle(enabled ? Color.tatBrand : Color(.tertiaryLabel))
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(label)
  }

  private func canShift(_ delta: Int) -> Bool {
    let calendar = Self.calendar
    let now = Self.startOfMonth(.now)
    guard let target = calendar.date(byAdding: .month, value: delta, to: month),
      let lower = calendar.date(byAdding: .month, value: -Self.reach, to: now),
      let upper = calendar.date(byAdding: .month, value: Self.reach, to: now)
    else { return false }
    return target >= lower && target <= upper
  }

  private func shift(_ delta: Int) {
    guard canShift(delta), let target = Self.calendar.date(byAdding: .month, value: delta, to: month) else { return }
    withAnimation(.easeInOut(duration: 0.2)) { month = target }
  }

  private static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = L10n.locale
    return calendar
  }

  private static func startOfMonth(_ date: Date) -> Date {
    calendar.dateInterval(of: .month, for: date)?.start ?? date
  }

  /// 前後補空格湊滿整週；nil 是不屬於這個月的格子。
  private static func cells(for month: Date) -> [Date?] {
    let calendar = self.calendar
    guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
    let leading = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
    var cells = [Date?](repeating: nil, count: leading)
    for day in range {
      cells.append(calendar.date(byAdding: .day, value: day - 1, to: month))
    }
    while cells.count % 7 != 0 { cells.append(nil) }
    return cells
  }

  private static func weekdaySymbols() -> [String] {
    let calendar = self.calendar
    let symbols = calendar.shortStandaloneWeekdaySymbols
    let first = calendar.firstWeekday - 1
    return Array(symbols[first...] + symbols[..<first])
  }

  private static func monthTitle(_ month: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = L10n.locale
    formatter.setLocalizedDateFormatFromTemplate("yMMMM")
    return formatter.string(from: month)
  }

  private static func fullDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = L10n.locale
    formatter.dateStyle = .full
    return formatter.string(from: date)
  }
}
