import SwiftUI

/// 信件列的「更多」，照 iOS 信件 App 用 sheet：上面是這一封，下面是動作。動作照 `MailListPage._showActions`；
/// 刪除只是搬到回收筒，救得回來，所以不再確認一次。
struct MailRowActionsSheet: View {
  enum Action {
    case toggleSeen, move, archive, trash
  }

  let row: MailRow
  let onSelect: (Action) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    SheetStack {
      List {
        Section {
          VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
              Text(row.from)
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
              Text(row.time)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            Text(row.subject)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          .padding(.vertical, 4)
        }
        Section {
          action(row.unread ? L10n.mailMarkRead : L10n.mailMarkUnread, row.unread ? Lucide.mailOpen : Lucide.mail, .toggleSeen)
          action(L10n.mailMoveToFolder, Lucide.folder, .move)
          action(L10n.mailFolderArchive, Lucide.archive, .archive)
        }
        Section {
          action(L10n.delete, Lucide.trash2, .trash, destructive: true)
        }
      }
    }
  }

  /// 先交出去再關：要換到資料夾選單的話，呼叫端得等這張關掉才開得出下一張。
  private func action(_ title: String, _ icon: LucideIcon, _ action: Action, destructive: Bool = false) -> some View {
    Button(role: destructive ? .destructive : nil) {
      onSelect(action)
      dismiss()
    } label: {
      Label {
        Text(title)
      } icon: {
        LucideImage(icon, size: 20)
          .foregroundStyle(destructive ? Color(.systemRed) : Color.tatBrand)
      }
    }
  }
}
