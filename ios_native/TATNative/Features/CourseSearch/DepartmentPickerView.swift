import SwiftUI

/// 系所篩選。Flutter 版是學院、系所各一頁；這裡收成一頁，展開學院看系所，選完直接回篩選頁。
struct DepartmentPickerView: View {
  let client: CourseSearchClient
  let selected: CourseSearchOption?
  let onPick: (CourseSearchOption?) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var colleges: [CourseSearchOption]?
  @State private var departments: [String: [CourseSearchOption]] = [:]
  @State private var expanded: Set<String> = []

  var body: some View {
    List {
      Section {
        CheckRow(label: L10n.courseSearchDepartmentAny, isSelected: selected == nil) { pick(nil) }
      }
      if let colleges, !colleges.isEmpty {
        Section(L10n.courseSearchCollege) {
          ForEach(colleges, id: \.no) { college in
            DisclosureGroup(isExpanded: isExpanded(college)) {
              departmentRows(college)
            } label: {
              Text(college.name)
            }
          }
        }
      }
    }
    .overlay {
      if colleges == nil {
        ProgressView()
      } else if colleges?.isEmpty == true {
        ContentUnavailableView {
          Label {
            Text(L10n.networkError)
          } icon: {
            LucideImage(Lucide.wifiOff, size: 44)
          }
        } actions: {
          Button(L10n.restart) { Task { await loadColleges() } }
        }
      }
    }
    .navigationTitle(L10n.courseSearchDepartment)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      if colleges == nil { await loadColleges() }
    }
  }

  @ViewBuilder private func departmentRows(_ college: CourseSearchOption) -> some View {
    switch departments[college.no] {
    case .none:
      ProgressView()
        .frame(maxWidth: .infinity)
        .task { await loadDepartments(college) }
    case .some(let list) where list.isEmpty:
      Button(L10n.restart) { departments[college.no] = nil }
    case .some(let list):
      ForEach(list, id: \.no) { department in
        CheckRow(label: department.name, isSelected: selected?.no == department.no) {
          pick(department)
        }
      }
    }
  }

  private func isExpanded(_ college: CourseSearchOption) -> Binding<Bool> {
    Binding(
      get: { expanded.contains(college.no) },
      set: { isOn in
        if isOn { expanded.insert(college.no) } else { expanded.remove(college.no) }
      }
    )
  }

  private func loadColleges() async {
    colleges = nil
    colleges = (try? await client.colleges()) ?? []
  }

  private func loadDepartments(_ college: CourseSearchOption) async {
    departments[college.no] = (try? await client.departments(collegeNo: college.no)) ?? []
  }

  private func pick(_ department: CourseSearchOption?) {
    onPick(department)
    dismiss()
  }
}
