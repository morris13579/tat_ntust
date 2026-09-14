import Flutter

/// 測驗詳情的核心呼叫。
@MainActor
final class QuizClient {
  private let api: TatQuizApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatQuizApi(binaryMessenger: messenger)
  }

  func detail(courseId: String, quizId: Int64, refresh: Bool) async throws -> QuizDetailResult {
    try await pigeonCall { api.detail(courseId: courseId, quizId: quizId, refresh: refresh, completion: $0) }
  }

  func answerLink(courseId: String, quizId: Int64) async throws -> WebLink? {
    try await pigeonCall { api.answerLink(courseId: courseId, quizId: quizId, completion: $0) }
  }
}
