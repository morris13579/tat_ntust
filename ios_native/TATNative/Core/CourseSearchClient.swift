import Flutter

/// 導入其他課程與模擬排課搜尋的核心呼叫。
@MainActor
final class CourseSearchClient {
  private let api: TatCourseSearchApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatCourseSearchApi(binaryMessenger: messenger)
  }

  /// [draftId] 不是 nil 時加進那一份模擬課表。
  func start(draftId: String?) async throws -> CourseSearchStart? {
    try await pigeonCall { api.start(draftId: draftId, completion: $0) }
  }

  func search(
    _ filter: CourseFilter, hideConflict: Bool, slots: Set<TimeSlot>
  ) async throws -> CourseSearchResults? {
    try await pigeonCall {
      api.search(filter: filter, hideConflict: hideConflict, slots: Array(slots), completion: $0)
    }
  }

  func results(hideConflict: Bool, slots: Set<TimeSlot>) async throws -> CourseSearchResults {
    try await pigeonCall {
      api.results(hideConflict: hideConflict, slots: Array(slots), completion: $0)
    }
  }

  func add(courseId: String) async throws -> CourseSearchChange {
    try await pigeonCall { api.add(courseId: courseId, completion: $0) }
  }

  func remove(courseId: String) async throws -> CourseSearchChange {
    try await pigeonCall { api.remove(courseId: courseId, completion: $0) }
  }

  func colleges() async throws -> [CourseSearchOption] {
    try await pigeonCall { api.colleges(completion: $0) }
  }

  func departments(collegeNo: String) async throws -> [CourseSearchOption] {
    try await pigeonCall { api.departments(collegeNo: collegeNo, completion: $0) }
  }
}
