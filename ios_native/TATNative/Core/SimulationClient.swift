import Flutter

/// 模擬排課的核心呼叫。
@MainActor
final class SimulationClient {
  private let api: TatSimulationApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatSimulationApi(binaryMessenger: messenger)
  }

  func drafts() async throws -> [DraftTableInfo] {
    try await pigeonCall { api.drafts(completion: $0) }
  }

  func semesters() async throws -> [String] {
    try await pigeonCall { api.semesters(completion: $0) }
  }

  func open(semester: String) async throws -> SimulationState {
    try await pigeonCall { api.open(semester: semester, completion: $0) }
  }

  func draft(id: String) async throws -> SimulationState? {
    try await pigeonCall { api.draft(id: id, completion: $0) }
  }

  func removeCourse(draftId: String, courseId: String) async throws -> SimulationState? {
    try await pigeonCall { api.removeCourse(id: draftId, courseId: courseId, completion: $0) }
  }

  func deleteDraft(id: String) async throws {
    try await pigeonCall { api.deleteDraft(id: id, completion: $0) }
  }
}
