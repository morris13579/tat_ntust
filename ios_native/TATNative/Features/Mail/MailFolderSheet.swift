import SwiftUI

/// 切換資料夾與「移到⋯」共用，照 `mail_folder_sheet.dart`：空的資料夾預設收起來，
/// 實測七個資料夾裡六個是 0 封，全部攤開的話整張選單有四分之三在說「這裡沒有東西」。
struct MailFolderSheet: View {
  let title: String
  let folders: [MailFolderRow]
  let selected: String
  let onPick: (String) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var showEmpty = false

  var body: some View {
    let hidden = folders.filter(\.empty)
    SheetStack(title: title) {
      List {
        Section {
          ForEach(folders.filter { !$0.empty }, id: \.path) { row($0) }
        }
        if !hidden.isEmpty {
          Section {
            if showEmpty {
              ForEach(hidden, id: \.path) { row($0) }
            }
            Button {
              withAnimation(.easeOut(duration: 0.2)) { showEmpty.toggle() }
            } label: {
              HStack {
                Text(showEmpty ? L10n.hideEmptyFolders : L10n.showEmptyFolders(String(hidden.count)))
                Spacer(minLength: 8)
                LucideImage(showEmpty ? Lucide.chevronUp : Lucide.chevronDown, size: 18)
              }
            }
          }
        }
      }
    }
  }

  private func row(_ folder: MailFolderRow) -> some View {
    CheckRow(
      label: folder.label, supporting: folder.count, icon: folder.inbox ? Lucide.inbox : Lucide.folder,
      isSelected: folder.path == selected
    ) {
      dismiss()
      onPick(folder.path)
    }
  }
}
