import Flutter

/// 資訊系統的核心呼叫。
@MainActor
final class SubSystemClient {
  private let api: TatSubSystemApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatSubSystemApi(binaryMessenger: messenger)
  }

  func tree() async throws -> ServiceTree {
    try await pigeonCall { api.tree(completion: $0) }
  }
}
