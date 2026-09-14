import Flutter

/// 空教室的核心呼叫。
@MainActor
final class ClassroomClient {
  private let api: TatClassroomApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatClassroomApi(binaryMessenger: messenger)
  }

  func start() async throws -> ClassroomSetup {
    try await pigeonCall { api.start(completion: $0) }
  }

  func now() async throws -> ClassroomNow {
    try await pigeonCall { api.now(completion: $0) }
  }

  func day(
    campus: String, building: String, date: String, section: Int64, run: ClassroomRun, refresh: Bool
  ) async throws -> ClassroomDay {
    try await pigeonCall {
      api.day(
        campusCode: campus, buildingCode: building, date: date, section: section, run: run,
        refresh: refresh, completion: $0)
    }
  }

  func rememberBuilding(_ code: String) async {
    _ = try? await pigeonCall { api.rememberBuilding(code: code, completion: $0) }
  }

  func rememberLayout(_ layout: ClassroomLayout) async {
    _ = try? await pigeonCall { api.rememberLayout(layout: layout, completion: $0) }
  }
}
