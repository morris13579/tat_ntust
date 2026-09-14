import Flutter

/// 啟動時的公告彈窗與更新提示的核心呼叫。
@MainActor
final class AppNoticeClient {
  private let api: TatAppNoticeApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatAppNoticeApi(binaryMessenger: messenger)
  }

  func launchAnnouncement(test: Bool) async throws -> LaunchAnnouncement? {
    try await pigeonCall { api.launchAnnouncement(test: test, completion: $0) }
  }

  func markAnnouncementRead() async throws {
    try await pigeonCall { api.markAnnouncementRead(completion: $0) }
  }

  func updateOffer(manual: Bool) async throws -> UpdateOffer? {
    try await pigeonCall { api.updateOffer(manual: manual, completion: $0) }
  }

  func ignoreUpdate() async throws {
    try await pigeonCall { api.ignoreUpdate(completion: $0) }
  }

  func refreshRemoteConfig() async throws {
    try await pigeonCall { api.refreshRemoteConfig(completion: $0) }
  }
}
