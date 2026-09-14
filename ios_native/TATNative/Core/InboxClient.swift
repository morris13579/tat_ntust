import Flutter

/// 通知中心的核心呼叫。
@MainActor
final class InboxClient {
  private let api: TatInboxApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatInboxApi(binaryMessenger: messenger)
  }

  func load() async throws -> InboxState {
    try await pigeonCall { api.load(completion: $0) }
  }

  func refresh() async throws -> InboxState {
    try await pigeonCall { api.refresh(completion: $0) }
  }

  func retryNotifications() async throws -> InboxState {
    try await pigeonCall { api.retryNotifications(completion: $0) }
  }

  func markRead(id: Int64) async throws -> InboxState {
    try await pigeonCall { api.markRead(id: id, completion: $0) }
  }

  func markAllRead() async throws -> InboxMarkAll {
    try await pigeonCall { api.markAllRead(completion: $0) }
  }

  func openLink(id: Int64) async throws -> WebLink? {
    try await pigeonCall { api.openLink(id: id, completion: $0) }
  }

  func badge(force: Bool) async throws -> Int64 {
    try await pigeonCall { api.badge(force: force, completion: $0) }
  }

  func previewItems() async throws -> [InboxPreviewItem] {
    try await pigeonCall { api.previewItems(completion: $0) }
  }

  func startPreview(index: Int) async throws -> InboxState {
    try await pigeonCall { api.startPreview(index: Int64(index), completion: $0) }
  }
}
