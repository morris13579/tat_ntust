import Flutter

/// 討論串、回覆、編輯與刪除的核心呼叫。
@MainActor
final class ForumClient {
  private let api: TatForumApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatForumApi(binaryMessenger: messenger)
  }

  func thread(
    courseId: String, forumId: Int64, discussionId: Int64, title: String, readOnly: Bool, refresh: Bool
  ) async throws -> ForumThread {
    try await pigeonCall {
      api.thread(
        courseId: courseId, forumId: forumId, discussionId: discussionId, title: title, readOnly: readOnly,
        refresh: refresh, completion: $0)
    }
  }

  func checkAttachments(discussionId: Int64, existingNames: [String], paths: [String]) async throws
    -> AttachmentCheck
  {
    try await pigeonCall {
      api.checkAttachments(discussionId: discussionId, existingNames: existingNames, paths: paths, completion: $0)
    }
  }

  func reply(discussionId: Int64, parentId: Int64?, text: String, paths: [String]) async throws -> ForumSendResult {
    try await pigeonCall {
      api.reply(discussionId: discussionId, parentId: parentId, text: text, paths: paths, completion: $0)
    }
  }

  func startEdit(discussionId: Int64, postId: Int64) async throws -> ForumEditStart {
    try await pigeonCall { api.startEdit(discussionId: discussionId, postId: postId, completion: $0) }
  }

  func saveEdit(
    discussionId: Int64, postId: Int64, subject: String, text: String, keepNames: [String], paths: [String]
  ) async throws -> ForumSendResult {
    try await pigeonCall {
      api.saveEdit(
        discussionId: discussionId, postId: postId, subject: subject, text: text, keepNames: keepNames,
        paths: paths, completion: $0)
    }
  }

  func deletePost(discussionId: Int64, postId: Int64) async throws -> ForumDeleteResult {
    try await pigeonCall { api.deletePost(discussionId: discussionId, postId: postId, completion: $0) }
  }

  func cancelTransfer(discussionId: Int64) async throws {
    try await pigeonCall { api.cancelTransfer(discussionId: discussionId, completion: $0) }
  }
}
