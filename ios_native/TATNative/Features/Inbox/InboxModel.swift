import Foundation
import Observation

@MainActor
@Observable
final class InboxModel {
  private(set) var state: InboxState?
  private(set) var expanded: Set<Int64> = []
  private(set) var markingAll = false
  var web: WebPage?

  let client: InboxClient
  /// 開發者選單的假資料預覽；nil 是正式的通知中心。
  let preview: Int?

  init(client: InboxClient, preview: Int? = nil) {
    self.client = client
    self.preview = preview
  }

  func load() async {
    let fetched: InboxState?
    if let preview {
      fetched = try? await client.startPreview(index: preview)
    } else {
      fetched = try? await client.load()
    }
    state =
      fetched
      ?? InboxState(
        notices: [], noticeUnread: false, sections: [], error: L10n.unknownError, signedIn: true, canMarkAll: false)
  }

  /// 預覽的資料是寫死的，沒有東西可以重抓。
  func refresh() async {
    guard preview == nil, let fetched = try? await client.refresh() else { return }
    state = fetched
  }

  func retry() async {
    guard let fetched = try? await client.retryNotifications() else { return }
    state = fetched
  }

  /// 已讀先改畫面、背景寫入：使用者的意圖是打開它，不是管理已讀狀態。失敗時核心會提示，狀態也會改回來。
  func tap(_ row: InboxRow) async {
    if row.unread {
      markLocally(row.id)
      Task {
        if let fetched = try? await client.markRead(id: row.id) { state = fetched }
      }
    }
    guard row.openable else {
      if expanded.contains(row.id) { expanded.remove(row.id) } else { expanded.insert(row.id) }
      return
    }
    guard let link = try? await client.openLink(id: row.id), let url = URL(string: link.url) else { return }
    web = WebPage(title: row.subject, url: url, fallbackURL: link.fallbackUrl.flatMap(URL.init(string:)))
  }

  func markAllRead(presenter: UiPresenter) async {
    markingAll = true
    defer { markingAll = false }
    guard let result = try? await client.markAllRead() else { return }
    state = result.state
    if result.ok { presenter.toast(L10n.notificationMarkAllReadDone, kind: .success) }
  }

  private func markLocally(_ id: Int64) {
    guard var current = state else { return }
    for section in current.sections.indices {
      for row in current.sections[section].rows.indices where current.sections[section].rows[row].id == id {
        current.sections[section].rows[row].unread = false
      }
    }
    state = current
  }
}
