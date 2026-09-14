import SwiftUI

/// 搜尋課程的篩選條件，照 `course_filter_page.dart`。每一項都對得上 querycourse 真的吃的參數。
struct CourseFilterView: View {
  let client: CourseSearchClient
  let onApply: (CourseFilter) -> Void

  @State private var draft: CourseFilter
  @Environment(\.dismiss) private var dismiss

  init(
    filter: CourseFilter, client: CourseSearchClient,
    onApply: @escaping (CourseFilter) -> Void
  ) {
    _draft = State(initialValue: filter)
    self.client = client
    self.onApply = onApply
  }

  var body: some View {
    List {
      Section(L10n.courseSearchDepartment) {
        NavigationLink {
          DepartmentPickerView(client: client, selected: draft.department) {
            draft.department = $0
          }
        } label: {
          Text(draft.department?.name ?? L10n.courseSearchDepartmentAny)
        }
      }

      Section(L10n.courseSearchLevel) {
        ForEach(ProgramLevel.allCases, id: \.self) { level in
          CheckRow(label: CourseSearchText.level(level), isSelected: draft.level == level) {
            draft.level = level
          }
        }
      }

      Section(L10n.courseSearchOptions) {
        Toggle(L10n.courseSearchForeignLanguage, isOn: $draft.foreignLanguageOnly)
        Toggle(L10n.courseSearchGeneral, isOn: $draft.generalOnly)
        Toggle(L10n.courseSearchIntensive, isOn: $draft.intensiveOnly)
        Toggle(L10n.courseSearchNtustOnly, isOn: $draft.ntustOnly)
      }

      Section(L10n.courseSearchDimension) {
        CheckRow(label: L10n.courseSearchDimensionAny, isSelected: draft.dimension == nil) {
          draft.dimension = nil
        }
        ForEach(GeDimension.allCases, id: \.self) { dimension in
          CheckRow(
            label: CourseSearchText.dimension(dimension),
            supporting: CourseSearchText.code(dimension),
            isSelected: draft.dimension == dimension
          ) {
            draft.dimension = dimension
          }
        }
      }
    }
    .navigationTitle(L10n.courseSearchFilterTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if draft.hasRefinements {
          Button(L10n.courseSearchReset) {
            var cleared = CourseFilter.empty
            cleared.keyword = draft.keyword
            draft = cleared
          }
          .toolbarButtonTint()
        }
      }
    }
    .bottomAction(L10n.courseSearchFilterApply) {
      onApply(draft)
      dismiss()
    }
  }
}
