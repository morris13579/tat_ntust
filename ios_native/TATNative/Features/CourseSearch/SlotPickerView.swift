import SwiftUI

/// 挑「哪幾節」，照 `course_slot_picker_page.dart`。節次篩選不在伺服器端，挑完回搜尋頁在本地篩；
/// 點星期或節次的標頭一次切換整欄或整列。
struct SlotPickerView: View {
  let days: [CourseGridDay]
  let sections: [CourseGridSection]
  let onApply: (Set<TimeSlot>) -> Void

  @State private var selected: Set<TimeSlot>
  @Environment(\.dismiss) private var dismiss

  init(
    days: [CourseGridDay], sections: [CourseGridSection], selected: Set<TimeSlot>,
    onApply: @escaping (Set<TimeSlot>) -> Void
  ) {
    self.days = days
    self.sections = sections
    self.onApply = onApply
    _selected = State(initialValue: selected)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        Text(L10n.courseSearchSlotHint)
          .font(.footnote)
          .foregroundStyle(.secondary)
        grid
      }
      .padding(16)
    }
    .navigationTitle(L10n.courseSearchSlot)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(L10n.courseSearchReset) { selected.removeAll() }
          .disabled(selected.isEmpty)
          .toolbarButtonTint()
      }
    }
    .bottomAction(L10n.courseSearchFilterApply) {
      onApply(selected)
      dismiss()
    }
    .sensoryFeedback(.selection, trigger: selected)
  }

  private var grid: some View {
    Grid(horizontalSpacing: 4, verticalSpacing: 4) {
      GridRow {
        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
        ForEach(days, id: \.index) { day in
          header(day.label, isFull: isFull(column(day)), style: .primary) { flip(column(day)) }
        }
      }
      ForEach(sections, id: \.index) { section in
        GridRow {
          header(section.label, isFull: isFull(row(section)), style: .secondary) {
            flip(row(section))
          }
          .frame(width: 34)
          ForEach(days, id: \.index) { day in
            cell(TimeSlot(day: day.index, section: section.index), label: "\(day.label) \(section.label)")
          }
        }
      }
    }
  }

  private func header(
    _ label: String, isFull: Bool, style: HierarchicalShapeStyle, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(label)
        .font(.footnote.weight(.medium).monospacedDigit())
        .foregroundStyle(isFull ? AnyShapeStyle(Color.tatBrand) : AnyShapeStyle(style))
        .frame(maxWidth: .infinity, minHeight: 34)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func cell(_ slot: TimeSlot, label: String) -> some View {
    let isOn = selected.contains(slot)
    return Button {
      flip([slot])
    } label: {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(isOn ? Color.tatBrand.opacity(0.18) : Color(.secondarySystemBackground))
        .frame(height: 34)
        .overlay {
          if isOn {
            LucideImage(Lucide.check, size: 16)
              .foregroundStyle(Color.tatBrand)
          }
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityAddTraits(isOn ? .isSelected : [])
  }

  private func column(_ day: CourseGridDay) -> [TimeSlot] {
    sections.map { TimeSlot(day: day.index, section: $0.index) }
  }

  private func row(_ section: CourseGridSection) -> [TimeSlot] {
    days.map { TimeSlot(day: $0.index, section: section.index) }
  }

  private func isFull(_ slots: [TimeSlot]) -> Bool {
    slots.allSatisfy(selected.contains)
  }

  /// 全滿就清掉，否則補滿，跟官方前端的全選／清除同一個意思。
  private func flip(_ slots: [TimeSlot]) {
    if isFull(slots) { selected.subtract(slots) } else { selected.formUnion(slots) }
  }
}
