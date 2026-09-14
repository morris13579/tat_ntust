import Flutter

/// 小工具要的課表。
@MainActor
final class WidgetClient {
  private let api: TatWidgetApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatWidgetApi(binaryMessenger: messenger)
  }

  /// 自己的課表，學期新的在前；沒登入時是空的。
  func timetables() async throws -> [WidgetTable] {
    try await pigeonCall { api.timetables(completion: $0) }
  }
}
