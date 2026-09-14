import Flutter

/// Moodle 通知設定的核心呼叫。
@MainActor
final class MoodleSettingClient {
  private let api: TatMoodleSettingApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatMoodleSettingApi(binaryMessenger: messenger)
  }

  func load() async throws -> MoodleSettings? {
    try await pigeonCall { api.load(completion: $0) }
  }

  func toggle(key: String, processor: String, enabled: Bool) async throws -> MoodleSettings? {
    try await pigeonCall {
      api.toggle(key: key, processor: processor, enabled: enabled, completion: $0)
    }
  }
}
