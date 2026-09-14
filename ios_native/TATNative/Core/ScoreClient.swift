import Flutter

/// 成績頁的核心呼叫。
@MainActor
final class ScoreClient {
  private let api: TatScoreApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatScoreApi(binaryMessenger: messenger)
  }

  func load(refresh: Bool) async throws -> ScoreReport {
    try await pigeonCall { api.load(refresh: refresh, completion: $0) }
  }

  func moodleGrades(refresh: Bool) async throws -> MoodleGrades {
    try await pigeonCall { api.moodleGrades(refresh: refresh, completion: $0) }
  }

  func courseScore(courseId: String) async throws -> MoodleCourseScore {
    try await pigeonCall { api.courseScore(courseId: courseId, completion: $0) }
  }
}
