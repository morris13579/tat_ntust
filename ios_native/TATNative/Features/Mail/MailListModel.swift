import Foundation
import Observation

enum MailSearchScope: Hashable {
  case folder, all
}

/// 信箱分頁。清單狀態由核心推過來（`MailCenter.list`），這裡只記設定與搜尋列上的東西，動作都交給核心。
@MainActor
@Observable
final class MailListModel {
  private(set) var status: MailStatus?
  private(set) var configured = false
  var searchText = ""
  var searchPresented = false
  var scope: MailSearchScope = .folder

  let client: MailClient
  let center: MailCenter
  /// 切分頁回來會再跑一次 `.task`，清單不該因此重開一份。
  @ObservationIgnored private var started = false

  init(client: MailClient, center: MailCenter) {
    self.client = client
    self.center = center
  }

  var state: MailListState? { center.list }

  func begin() async {
    guard !started else { return }
    started = true
    guard let status = try? await client.status() else {
      started = false
      return
    }
    self.status = status
    configured = status.configured
    if configured { try? await client.open() }
  }

  func setupDone() async {
    configured = true
    try? await client.open()
  }

  /// 核心說信箱密碼不見了：回設定頁，設定好之後重開一份清單。
  func lostSetup() {
    configured = false
  }

  func reload() async {
    try? await client.reload()
  }

  func openFolder(_ path: String) async {
    try? await client.openFolder(path)
  }

  func submitSearch() async {
    try? await client.search(searchText, allFolders: scope == .all)
  }

  /// 沒在搜尋時只記下範圍，不白跑一次連線。關掉搜尋列時範圍被重設的那一次也不算：
  /// 那時畫面上的關鍵字還沒清掉，照著它再搜一次會把人帶回搜尋結果。
  func scopeChanged() async {
    guard searchPresented, let keyword = state?.keyword else { return }
    try? await client.search(keyword, allFolders: scope == .all)
  }

  /// 清掉搜尋框的字：回到清單，範圍留著。
  func clearSearch() async {
    guard searchPresented, state?.keyword != nil else { return }
    try? await client.search("", allFolders: scope == .all)
  }

  func endSearch() async {
    scope = .folder
    try? await client.endSearch()
  }

  func loadMore() async {
    try? await client.loadMore()
  }

  func markSeen(_ row: MailRow) {
    guard row.unread else { return }
    Task { try? await client.markSeen(ref: row.ref) }
  }

  func toggleSeen(_ row: MailRow) async -> Bool {
    (try? await client.setSeen(ref: row.ref, seen: row.unread)) ?? false
  }

  func trash(_ row: MailRow) async -> Bool {
    (try? await client.moveToTrash(ref: row.ref)) ?? false
  }

  func archive(_ row: MailRow) async -> Bool {
    (try? await client.archive(ref: row.ref)) ?? false
  }

  func move(_ row: MailRow, to path: String) async -> Bool {
    (try? await client.moveToFolder(ref: row.ref, target: path)) ?? false
  }

  func recall(_ item: MailOutboxRow) async -> Bool {
    (try? await client.recall(id: item.id)) ?? false
  }

  func retry(_ item: MailOutboxRow) async {
    try? await client.retry(id: item.id)
  }
}
