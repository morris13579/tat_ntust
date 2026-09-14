import SwiftUI

/// 學期選單，照 Flutter 版的 `showSemesterSheet`。清單在打開之前就已經抓好
/// （見 `CourseTableModel.loadSemesters`）。
struct SemesterSheet: View {
  let model: CourseTableModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    SheetStack(title: L10n.selectSemester) {
      List {
        ForEach(model.semesters, id: \.self) { semester in
          CheckRow(label: semester, tabularFigures: true, isSelected: semester == model.grid?.semester) {
            dismiss()
            Task { await model.select(semester: semester) }
          }
        }
      }
    }
  }
}
