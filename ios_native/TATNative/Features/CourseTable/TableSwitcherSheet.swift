import SwiftUI

enum TableSwitchChoice {
  case mine(MyTable)
  case shared(SharedTableInfo)
  case draft(DraftTableInfo)
  case newDraft
  case manage
}

/// 課表切換器，照 `table_switcher_sheet.dart`：我的課表、他人課表、模擬課表各一區，最底下是管理課表。
/// 清單在打開之前就已經抓好（`CourseTableModel.loadSwitcher`）。
struct TableSwitcherSheet: View {
  let model: CourseTableModel
  let onSelect: (TableSwitchChoice) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    SheetStack(title: L10n.tableSwitcherTitle) {
      List {
        if !model.myTables.isEmpty {
          Section(L10n.tableSwitcherMine) {
            ForEach(model.myTables, id: \.self) { table in
              CheckRow(
                label: TableText.label(table),
                supporting: TableText.summary(courses: table.courseCount, credits: table.credits),
                tabularFigures: true,
                isSelected: model.isCurrent(table)
              ) { pick(.mine(table)) }
            }
          }
        }
        if !model.sharedTables.isEmpty {
          Section(L10n.tableSwitcherShared) {
            ForEach(model.sharedTables, id: \.id) { table in
              CheckRow(
                label: table.label, supporting: TableText.imported(table), tabularFigures: true, isSelected: false
              ) { pick(.shared(table)) }
            }
          }
        }
        Section(L10n.tableSwitcherDrafts) {
          ForEach(model.drafts, id: \.id) { draft in
            CheckRow(label: draft.label, supporting: draft.summary, isSelected: false) { pick(.draft(draft)) }
          }
          actionRow(Lucide.plus, L10n.simulationNew) { pick(.newDraft) }
        }
        Section {
          actionRow(Lucide.settings2, L10n.manageTablesTitle) { pick(.manage) }
        }
      }
    }
  }

  private func pick(_ choice: TableSwitchChoice) {
    onSelect(choice)
    dismiss()
  }

  /// 不是「選一份課表」而是「做一件事」的那幾列，所以有圖示、沒有打勾。
  private func actionRow(_ icon: LucideIcon, _ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Label {
        Text(label)
      } icon: {
        LucideImage(icon, size: 20)
      }
    }
  }
}
