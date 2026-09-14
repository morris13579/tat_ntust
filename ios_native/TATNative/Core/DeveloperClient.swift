import Flutter

/// 開發者選單的核心呼叫。
@MainActor
final class DeveloperClient {
  private let api: TatDeveloperApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatDeveloperApi(binaryMessenger: messenger)
  }

  func logs() async throws -> [LogEntry] {
    try await pigeonCall { api.logs(completion: $0) }
  }

  func clearLogs() async throws {
    try await pigeonCall { api.clearLogs(completion: $0) }
  }

  func httpCalls() async throws -> [HttpCallEntry] {
    try await pigeonCall { api.httpCalls(completion: $0) }
  }

  func clearHttpCalls() async throws {
    try await pigeonCall { api.clearHttpCalls(completion: $0) }
  }

  func storeEntries() async throws -> [StoreEntry] {
    try await pigeonCall { api.storeEntries(completion: $0) }
  }

  func setStoreValue(key: String, value: String) async throws {
    try await pigeonCall { api.setStoreValue(key: key, value: value, completion: $0) }
  }

  func removeStoreKey(_ key: String) async throws {
    try await pigeonCall { api.removeStoreKey(key: key, completion: $0) }
  }

  func reloadStore() async throws {
    try await pigeonCall { api.reloadStore(completion: $0) }
  }
}
