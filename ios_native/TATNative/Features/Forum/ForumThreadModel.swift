import Foundation
import Observation

@MainActor
@Observable
final class ForumThreadModel {
  private(set) var thread: ForumThread?
  /// 正在回覆哪一篇。nil ＝第一篇（預設）。
  var target: ForumPostItem?
  var text = ""
  /// 回覆列上已經挑好的附件，本機路徑。草稿活在這裡、不落地，離開這一頁就沒了。
  private(set) var attachments: [String] = []
  private(set) var sending = false
  var scrollTarget: Int64?
  var editing: ForumEditModel?
  var web: WebPage?

  let client: ForumClient
  let moodle: CourseMoodleClient
  let course: CourseRef
  let forumId: Int64
  let discussionId: Int64
  let initialTitle: String
  let readOnly: Bool
  @ObservationIgnored private let onListChanged: () -> Void

  init(
    client: ForumClient, moodle: CourseMoodleClient, course: CourseRef, forumId: Int64, discussionId: Int64,
    title: String, readOnly: Bool, onListChanged: @escaping () -> Void
  ) {
    self.client = client
    self.moodle = moodle
    self.course = course
    self.forumId = forumId
    self.discussionId = discussionId
    initialTitle = title
    self.readOnly = readOnly
    self.onListChanged = onListChanged
  }

  var title: String { thread?.title ?? initialTitle }
  var transferKey: String { "forum-\(discussionId)" }

  var hasDraft: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
  }

  /// 純附件回覆是合法的：一張照片本身就是內容。
  var canSend: Bool { !sending && hasDraft }

  func load(refresh: Bool) async {
    let fetched = try? await client.thread(
      courseId: course.courseId, forumId: forumId, discussionId: discussionId, title: initialTitle,
      readOnly: readOnly, refresh: refresh)
    thread =
      fetched
      ?? ForumThread(
        title: title, posts: thread?.posts ?? [], composer: .hidden,
        attach: ForumAttachRules(enabled: false, maxFiles: 0, hint: ""), error: L10n.unknownError,
        signedIn: true)
  }

  /// 瞄準某一篇：目標列換句話、那一篇捲到上緣並加外框。
  func aim(_ post: ForumPostItem) {
    target = post.depth == 0 ? nil : post
    scrollTarget = post.id
  }

  func addAttachments(_ paths: [String], presenter: UiPresenter) async {
    guard !paths.isEmpty,
      let check = try? await client.checkAttachments(
        discussionId: discussionId, existingNames: attachments.map { ($0 as NSString).lastPathComponent },
        paths: paths)
    else { return }
    attachments += check.accepted
    if !check.messages.isEmpty {
      presenter.toast(check.messages.joined(separator: "\n"), kind: .error)
    }
  }

  func removeAttachment(_ path: String) {
    attachments.removeAll { $0 == path }
  }

  /// 送出一則回覆。失敗時留在原地，字與附件原封不動。
  func send(transfers: TransferCenter, presenter: UiPresenter) async {
    guard canSend else { return }
    sending = true
    transfers.clear(transferKey)
    defer {
      sending = false
      transfers.clear(transferKey)
    }
    guard
      let result = try? await client.reply(
        discussionId: discussionId, parentId: target?.id, text: text, paths: attachments)
    else { return }
    if !result.messages.isEmpty {
      presenter.toast(result.messages.joined(separator: "\n"), kind: result.ok ? .info : .error)
    }
    guard result.ok else { return }
    text = ""
    attachments = []
    target = nil
    if let fresh = result.thread { thread = fresh }
    scrollTarget = result.scrollTo
  }

  /// 上傳階段可以取消：伺服器上什麼都還沒動。送出階段不行，沒有冪等鍵。
  func cancelUpload() async {
    try? await client.cancelTransfer(discussionId: discussionId)
  }

  func startEdit(_ post: ForumPostItem, presenter: UiPresenter) async {
    guard let start = try? await client.startEdit(discussionId: discussionId, postId: post.id) else { return }
    if let message = start.message { presenter.toast(message, kind: .error) }
    if let fresh = start.thread { thread = fresh }
    if let draft = start.draft {
      editing = ForumEditModel(client: client, moodle: moodle, course: course, discussionId: discussionId, draft: draft)
    }
  }

  func applyEdit(_ result: ForumSendResult) {
    if let fresh = result.thread { thread = fresh }
    if result.listChanged { onListChanged() }
  }

  /// 回 true 代表刪掉的是第一篇、整串沒了，要回清單。
  func delete(_ post: ForumPostItem, presenter: UiPresenter) async -> Bool {
    guard let result = try? await client.deletePost(discussionId: discussionId, postId: post.id) else {
      return false
    }
    if !result.messages.isEmpty {
      presenter.toast(result.messages.joined(separator: "\n"))
    }
    if let fresh = result.thread { thread = fresh }
    if result.closeThread { onListChanged() }
    return result.closeThread
  }

  func openInWeb() async {
    guard let link = try? await moodle.discussionWebLink(discussionId: discussionId),
      let url = URL(string: link.url)
    else { return }
    web = WebPage(title: title, url: url, fallbackURL: link.fallbackUrl.flatMap(URL.init(string:)))
  }
}

extension ForumPostItem: Identifiable {}
