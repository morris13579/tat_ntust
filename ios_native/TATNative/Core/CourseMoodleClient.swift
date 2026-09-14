import Flutter

/// 一門課 Moodle 分頁的核心呼叫。
@MainActor
final class CourseMoodleClient {
  private let api: TatCourseMoodleApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatCourseMoodleApi(binaryMessenger: messenger)
  }

  func directory(courseId: String) async throws -> CourseDirectory {
    try await pigeonCall { api.directory(courseId: courseId, completion: $0) }
  }

  func searchDirectory(courseId: String, query: String) async throws -> [CourseSectionItem] {
    try await pigeonCall { api.searchDirectory(courseId: courseId, query: query, completion: $0) }
  }

  func moduleFile(courseId: String, moduleId: Int64) async throws -> MoodleFileLink? {
    try await pigeonCall { api.moduleFile(courseId: courseId, moduleId: moduleId, completion: $0) }
  }

  func moduleUrl(courseId: String, moduleId: Int64) async throws -> String? {
    try await pigeonCall { api.moduleUrl(courseId: courseId, moduleId: moduleId, completion: $0) }
  }

  func moduleWebLink(courseId: String, moduleId: Int64) async throws -> WebLink? {
    try await pigeonCall { api.moduleWebLink(courseId: courseId, moduleId: moduleId, completion: $0) }
  }

  func folder(courseId: String, moduleId: Int64, path: String) async throws -> CourseFolder? {
    try await pigeonCall {
      api.folder(courseId: courseId, moduleId: moduleId, path: path, completion: $0)
    }
  }

  func page(courseId: String, moduleId: Int64) async throws -> CoursePage {
    try await pigeonCall { api.page(courseId: courseId, moduleId: moduleId, completion: $0) }
  }

  func feed(courseId: String) async throws -> CourseFeed {
    try await pigeonCall { api.feed(courseId: courseId, completion: $0) }
  }

  func filterFeed(courseId: String, kind: FeedKind?) async throws -> CourseFeed {
    try await pigeonCall { api.filterFeed(courseId: courseId, kind: kind, completion: $0) }
  }

  func forumDiscussions(forumId: Int64) async throws -> ForumDiscussions {
    try await pigeonCall { api.forumDiscussions(forumId: forumId, completion: $0) }
  }

  func assignments(courseId: String) async throws -> AssignmentList {
    try await pigeonCall { api.assignments(courseId: courseId, completion: $0) }
  }

  func assignmentStatuses(courseId: String) async throws -> AssignmentList {
    try await pigeonCall { api.assignmentStatuses(courseId: courseId, completion: $0) }
  }

  func cachedAssignments(courseId: String) async throws -> AssignmentList {
    try await pigeonCall { api.cachedAssignments(courseId: courseId, completion: $0) }
  }

  func discussionWebLink(discussionId: Int64) async throws -> WebLink {
    try await pigeonCall { api.discussionWebLink(discussionId: discussionId, completion: $0) }
  }

  func linkTarget(url: String) async throws -> MoodleLinkTarget {
    try await pigeonCall { api.linkTarget(url: url, completion: $0) }
  }

  func htmlImages(html: String) async throws -> [String] {
    try await pigeonCall { api.htmlImages(html: html, completion: $0) }
  }

  func isAutologinScript(url: String) async throws -> Bool {
    try await pigeonCall { api.isAutologinScript(url: url, completion: $0) }
  }
}
