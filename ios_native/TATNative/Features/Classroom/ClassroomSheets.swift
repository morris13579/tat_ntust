import SwiftUI

/// 改時段，照 `classroom_time_sheet.dart`：日期只給往後兩週（借用系統的表也只排到那裡），
/// 節次一定帶時間，「回到現在」隨時點得到。
struct ClassroomTimeSheet: View {
  let sections: [ClassSection]
  let onApply: (String, Int64) -> Void
  let onBackToNow: () -> Void

  @State private var date: String
  @State private var section: Int64
  @Environment(\.dismiss) private var dismiss

  private struct DayChoice: Identifiable {
    let id: String
    let weekday: String
    let monthDay: String
  }

  init(
    date: String, section: Int64, sections: [ClassSection], onApply: @escaping (String, Int64) -> Void,
    onBackToNow: @escaping () -> Void
  ) {
    _date = State(initialValue: date)
    _section = State(initialValue: section)
    self.sections = sections
    self.onApply = onApply
    self.onBackToNow = onBackToNow
  }

  var body: some View {
    SheetStack(title: L10n.classroomChangeTime) {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          label(L10n.classroomDate)
          ScrollView(.horizontal) {
            HStack(spacing: 8) {
              ForEach(days) { day in
                chip(top: day.weekday, bottom: day.monthDay, selected: day.id == date) { date = day.id }
                  .frame(width: 64, height: 66)
              }
            }
            .padding(.horizontal, 20)
          }
          .scrollIndicators(.hidden)
          .padding(.horizontal, -20)
          label(L10n.classroomSection)
            .padding(.top, 20)
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(Array(sections.enumerated()), id: \.offset) { index, item in
              chip(top: item.label, bottom: item.start, selected: Int64(index) == section, emphasiseTop: true) {
                section = Int64(index)
              }
              .frame(height: 58)
            }
          }
        }
        .padding(.horizontal, 20)
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(L10n.classroomBackToNow) {
            onBackToNow()
            dismiss()
          }
          .toolbarButtonTint()
        }
      }
      .bottomAction(L10n.classroomApplyTime) {
        onApply(date, section)
        dismiss()
      }
    }
  }

  private var days: [DayChoice] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let weekday = DateFormatter()
    weekday.locale = L10n.locale
    weekday.setLocalizedDateFormatFromTemplate("EEE")
    let monthDay = DateFormatter()
    monthDay.locale = L10n.locale
    monthDay.setLocalizedDateFormatFromTemplate("Md")
    return (0..<14).compactMap { offset in
      guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
      return DayChoice(
        id: CalendarKey.string(for: day), weekday: weekday.string(from: day),
        monthDay: monthDay.string(from: day))
    }
  }

  private func label(_ text: String) -> some View {
    Text(text)
      .font(.sectionHeader)
      .foregroundStyle(.secondary)
      .padding(.bottom, 8)
  }

  /// 上面一行代號、下面一行時間。
  private func chip(
    top: String, bottom: String, selected: Bool, emphasiseTop: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 2) {
        Text(top)
          .font(emphasiseTop ? .headline : .caption)
          .foregroundStyle(selected ? Color.white : (emphasiseTop ? Color.primary : Color.secondary))
        Text(bottom)
          .font(emphasiseTop ? .caption : .headline)
          .foregroundStyle(selected ? Color.white : (emphasiseTop ? Color.secondary : Color.primary))
      }
      .monospacedDigit()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        selected ? Color.tatBrand : Color(.tertiarySystemFill),
        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// 一間教室那一天的明細，照 `classroom_room_sheet.dart`：一整天檢視不寫課名，點一列才看。
struct ClassroomRoomSheet: View {
  let room: ClassroomRoom
  let sections: [ClassSection]
  let section: Int

  var body: some View {
    SheetStack(title: room.name) {
      List {
        ForEach(Array(room.slots.enumerated()), id: \.offset) { index, slot in
          let isNow = index == section
          HStack(spacing: 12) {
            Text(index < sections.count ? "\(sections[index].label)  \(sections[index].start)" : "")
              .font(.subheadline.monospacedDigit())
              .foregroundStyle(isNow ? Color.tatBrand : Color.secondary)
              .frame(width: 96, alignment: .leading)
            Text(slot.free ? L10n.classroomFreeCell : (slot.course.isEmpty ? L10n.classroomLegendBooked : slot.course))
              .foregroundStyle(slot.free ? Color.secondary : Color.primary)
              .lineLimit(1)
            Spacer(minLength: 0)
            if !slot.teacher.isEmpty {
              Text(slot.teacher)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
          .listRowBackground(isNow ? Color.tatBrand.opacity(0.12) : nil)
        }
      }
    }
  }
}
