import Flutter

/// 作業詳情與繳交的核心呼叫。
@MainActor
final class AssignmentClient {
  private let api: TatAssignmentApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatAssignmentApi(binaryMessenger: messenger)
  }

  func detail(courseId: String, assignId: Int64, refresh: Bool) async throws -> AssignmentDetailResult {
    try await pigeonCall { api.detail(courseId: courseId, assignId: assignId, refresh: refresh, completion: $0) }
  }

  func submitForGrading(assignId: Int64, acceptStatement: Bool) async throws -> AssignWriteResult {
    try await pigeonCall {
      api.submitForGrading(assignId: assignId, acceptStatement: acceptStatement, completion: $0)
    }
  }

  func removeSubmission(assignId: Int64) async throws -> AssignWriteResult {
    try await pigeonCall { api.removeSubmission(assignId: assignId, completion: $0) }
  }

  func copyPrevious(assignId: Int64) async throws -> AssignWriteResult {
    try await pigeonCall { api.copyPrevious(assignId: assignId, completion: $0) }
  }

  func webLink(assignId: Int64) async throws -> WebLink? {
    try await pigeonCall { api.webLink(assignId: assignId, completion: $0) }
  }

  func openSubmit(assignId: Int64) async throws -> SubmitState? {
    try await pigeonCall { api.openSubmit(assignId: assignId, completion: $0) }
  }

  func setText(assignId: Int64, text: String) async throws -> SubmitState {
    try await pigeonCall { api.setText(assignId: assignId, text: text, completion: $0) }
  }

  func setAccepted(assignId: Int64, accepted: Bool) async throws -> SubmitState {
    try await pigeonCall { api.setAccepted(assignId: assignId, accepted: accepted, completion: $0) }
  }

  func addFiles(assignId: Int64, paths: [String]) async throws -> SubmitState {
    try await pigeonCall { api.addFiles(assignId: assignId, paths: paths, completion: $0) }
  }

  func toggleFile(assignId: Int64, index: Int64) async throws -> SubmitState {
    try await pigeonCall { api.toggleFile(assignId: assignId, index: index, completion: $0) }
  }

  func saveConfirmation(assignId: Int64) async throws -> String? {
    try await pigeonCall { api.saveConfirmation(assignId: assignId, completion: $0) }
  }

  func save(assignId: Int64) async throws -> SubmitOutcome {
    try await pigeonCall { api.save(assignId: assignId, completion: $0) }
  }

  func cancelSubmit(assignId: Int64) async throws {
    try await pigeonCall { api.cancelSubmit(assignId: assignId, completion: $0) }
  }

  func startConfirmation(assignId: Int64) async throws -> String {
    try await pigeonCall { api.startConfirmation(assignId: assignId, completion: $0) }
  }

  func start(assignId: Int64) async throws -> SubmitState {
    try await pigeonCall { api.start(assignId: assignId, completion: $0) }
  }

  func closeSubmit(assignId: Int64) async throws -> AssignWriteResult {
    try await pigeonCall { api.closeSubmit(assignId: assignId, completion: $0) }
  }
}
