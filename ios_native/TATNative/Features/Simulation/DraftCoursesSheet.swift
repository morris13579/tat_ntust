import SwiftUI

/// 草稿裡目前選了哪些課，照 `draft_course_sheet.dart`：摘要只寫得下幾門幾學分，格子上一門跨三節的課又被切成三格。
struct DraftCoursesSheet: View {
  let model: SimulationModel

  var body: some View {
    SheetStack(title: L10n.simulationDraftListTitle) {
      List {
        if model.state.courses.isEmpty {
          SectionEmptyState(message: L10n.simulationEmptyHint, icon: Lucide.flaskConical)
            .listRowBackground(Color.clear)
        } else {
          ForEach(model.state.courses, id: \.id) { course in
            HStack(spacing: 8) {
              VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                  .foregroundStyle(course.clashes ? Color(.systemRed) : Color.primary)
                if !course.supporting.isEmpty {
                  Text(course.supporting)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              Button {
                Task { await model.remove(courseId: course.id) }
              } label: {
                LucideImage(Lucide.x, size: 18)
                  .foregroundStyle(.secondary)
                  .frame(width: 44, height: 44)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.borderless)
              .accessibilityLabel(L10n.simulationRemoveCourse)
              .disabled(model.busy)
            }
          }
        }
      }
    }
  }
}

/// 新增模擬課表要選學期：querycourse 是分學期的，草稿的學期跟搜尋的學期不一致的話，排進去的課根本不存在。
struct DraftSemesterSheet: View {
  let semesters: [String]
  let current: String?
  let onSelect: (String) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    SheetStack(title: L10n.selectSemester) {
      List {
        ForEach(semesters, id: \.self) { semester in
          CheckRow(label: semester, tabularFigures: true, isSelected: semester == current) {
            onSelect(semester)
            dismiss()
          }
        }
      }
    }
  }
}
