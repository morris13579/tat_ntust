import Flutter

/// 課程詳細資訊與修課學生的核心呼叫。
@MainActor
final class CourseDetailClient {
  private let api: TatCourseDetailApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatCourseDetailApi(binaryMessenger: messenger)
  }

  func detail(courseId: String, semester: String) async throws -> CourseDetailResult {
    try await pigeonCall { api.detail(courseId: courseId, semester: semester, completion: $0) }
  }

  func members(courseId: String, refresh: Bool) async throws -> CourseMembers {
    try await pigeonCall { api.members(courseId: courseId, refresh: refresh, completion: $0) }
  }

  func filterMembers(courseId: String, query: String) async throws -> [CourseMember] {
    try await pigeonCall { api.filterMembers(courseId: courseId, query: query, completion: $0) }
  }
}
