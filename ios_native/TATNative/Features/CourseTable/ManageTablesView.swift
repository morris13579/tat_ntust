import SwiftUI

/// 管理課表，照 `manage_tables_page.dart`。自己的課表刪掉只是清掉本機快取，下次選那個學期會再抓；
/// 他人課表是掃描當下的快照，刪掉就沒了。
struct ManageTablesView: View {
  let model: CourseTableModel
  var onScan: () -> Void

  @State private var pendingDelete: PendingDelete?

  private enum PendingDelete: Identifiable {
    case mine(MyTable)
    case shared(SharedTableInfo)
    case draft(DraftTableInfo)

    var id: String {
      switch self {
      case .mine(let table): "mine-\(table.studentId)-\(table.semester)"
      case .shared(let table): "shared-\(table.id)"
      case .draft(let draft): "draft-\(draft.id)"
      }
    }

    var label: String {
      switch self {
      case .mine(let table): TableText.label(table)
      case .shared(let table): table.label
      case .draft(let draft): draft.label
      }
    }
  }

  var body: some View {
    List {
      Section {
        ForEach(model.myTables, id: \.self) { table in
          row(Lucide.graduationCap, TableText.label(table),
              TableText.summary(courses: table.courseCount, credits: table.credits)) {
            // 目前這一份不給刪：刪掉之後畫面上還顯示著它，狀態會對不起來。
            if model.isCurrent(table) {
              Text(L10n.manageTablesCurrent)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.tatBrand)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.tatBrand.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            } else {
              deleteButton { pendingDelete = .mine(table) }
            }
          }
        }
      } header: {
        Text(L10n.manageTablesMine)
      } footer: {
        note(L10n.manageTablesMineHint)
      }

      Section {
        ForEach(model.sharedTables, id: \.id) { table in
          row(Lucide.users, table.label, TableText.imported(table)) {
            deleteButton { pendingDelete = .shared(table) }
          }
        }
        Button(action: onScan) {
          HStack(spacing: 10) {
            LucideImage(Lucide.scanLine, size: 20).frame(width: 28)
            Text(L10n.scanTableTitle)
          }
          .foregroundStyle(Color.tatBrand)
        }
      } header: {
        Text(L10n.manageTablesShared)
      } footer: {
        note(L10n.manageTablesSharedHint)
      }

      if !model.drafts.isEmpty {
        Section {
          ForEach(model.drafts, id: \.id) { draft in
            row(Lucide.flaskConical, draft.label, draft.summary) {
              deleteButton { pendingDelete = .draft(draft) }
            }
          }
        } header: {
          Text(L10n.manageTablesDrafts)
        } footer: {
          note(L10n.manageTablesDraftsHint)
        }
      }
    }
    .navigationTitle(L10n.manageTablesTitle)
    .navigationBarTitleDisplayMode(.inline)
    .alert(
      pendingDelete?.label ?? "",
      isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
      presenting: pendingDelete
    ) { item in
      Button(L10n.delete, role: .destructive) {
        Task {
          switch item {
          case .mine(let table): await model.delete(table)
          case .shared(let table): await model.deleteShared(table)
          case .draft(let draft): await model.deleteDraft(draft)
          }
        }
      }
      Button(L10n.cancel, role: .cancel) {}
    }
    .task { await model.loadSwitcher() }
    .analyticsScreen("/ManageTablesPage")
  }

  private func row<Trailing: View>(
    _ icon: LucideIcon, _ label: String, _ supporting: String,
    @ViewBuilder trailing: () -> Trailing
  ) -> some View {
    HStack(spacing: 10) {
      LucideImage(icon, size: 20)
        .foregroundStyle(Color.tatBrand)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 2) {
        Text(label).font(.body.monospacedDigit())
        Text(supporting).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
      trailing()
    }
  }

  private func deleteButton(_ action: @escaping () -> Void) -> some View {
    Button(action: action) {
      LucideImage(Lucide.trash2, size: 20)
        .foregroundStyle(Color(.systemRed))
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(L10n.delete)
  }

  private func note(_ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      LucideImage(Lucide.info, size: 14)
        .alignedToFirstTextLine(.footnote)
      Text(text)
    }
  }
}
