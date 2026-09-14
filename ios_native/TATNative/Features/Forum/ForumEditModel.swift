import Foundation
import Observation

@MainActor
@Observable
final class ForumEditModel {
  let draft: ForumEditDraft
  var subject: String
  var text: String
  /// 使用者決定留下的既有附件。
  private(set) var kept: [MoodleFileRow]
  /// 這次新挑的檔案，本機路徑。
  private(set) var added: [String] = []
  private(set) var sending = false
  private(set) var editorReady = false
  private(set) var editorFailed = false
  /// 使用者真的動過編輯器的內容，不是只移動游標：放棄草稿的確認靠它。
  private(set) var edited = false
  var activeFormats: Set<String> = []
  private(set) var sourceMode = false
  /// 重試時換一個，讓編輯器整個重建而不是沿用壞掉的那一個。
  private(set) var editorGeneration = 0
  @ObservationIgnored let editor = RichEditorController()

  let client: ForumClient
  let moodle: CourseMoodleClient
  let course: CourseRef
  let discussionId: Int64

  init(client: ForumClient, moodle: CourseMoodleClient, course: CourseRef, discussionId: Int64, draft: ForumEditDraft) {
    self.client = client
    self.moodle = moodle
    self.course = course
    self.discussionId = discussionId
    self.draft = draft
    subject = draft.subject
    text = draft.text ?? ""
    kept = draft.attachments
  }

  var isRich: Bool { draft.mode == .rich }
  var transferKey: String { "forum-\(discussionId)" }
  var total: Int { kept.count + added.count }

  /// 編輯的「草稿」是「跟帶進來的初值不一樣」，不是「非空」。
  var hasDraft: Bool {
    edited || !added.isEmpty || subject != draft.subject || kept.count != draft.attachments.count
      || (!isRich && text != (draft.text ?? ""))
  }

  /// 底列上唯一的「為什麼現在存不了」，優先序由上而下。
  var blockReason: String? {
    if isRich {
      if editorFailed { return L10n.forumEditorLoadFailed }
      if !editorReady { return L10n.forumEditorLoading }
    }
    if draft.isTopicPost && subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return L10n.forumSubjectRequired
    }
    if !isRich && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && total == 0 {
      return L10n.forumMessageRequired
    }
    return nil
  }

  var canSave: Bool { !sending && blockReason == nil }

  func editorLoaded() { editorReady = true }
  func editorBroke() { editorFailed = true }
  func editorInput() { edited = true }

  func retryEditor() {
    editorFailed = false
    editorReady = false
    sourceMode = false
    editorGeneration += 1
  }

  func toggleSource() {
    sourceMode.toggle()
    activeFormats = []
    editor.setSourceMode(sourceMode)
  }

  func addAttachments(_ paths: [String], presenter: UiPresenter) async {
    guard !paths.isEmpty,
      let check = try? await client.checkAttachments(
        discussionId: discussionId,
        existingNames: kept.map(\.name) + added.map { ($0 as NSString).lastPathComponent }, paths: paths)
    else { return }
    added += check.accepted
    if !check.messages.isEmpty {
      presenter.toast(check.messages.joined(separator: "\n"), kind: .error)
    }
  }

  func removeKept(_ file: MoodleFileRow) {
    kept.removeAll { $0 == file }
  }

  func removeAdded(_ path: String) {
    added.removeAll { $0 == path }
  }

  /// 成功時回傳結果，頁面關掉；失敗一律留在原地，內容一個字都不動。
  func save(transfers: TransferCenter, presenter: UiPresenter) async -> ForumSendResult? {
    guard canSave else { return nil }
    let body: String
    if isRich {
      // 拿不到內容時絕對不能當成空字串送出去：伺服器對空 message 是「不改」然後照樣回成功。
      guard let html = await editor.content() else {
        presenter.toast(L10n.forumEditorLoadFailed, kind: .error)
        return nil
      }
      body = html
    } else {
      body = text
    }
    sending = true
    transfers.clear(transferKey)
    defer {
      sending = false
      transfers.clear(transferKey)
    }
    guard
      let result = try? await client.saveEdit(
        discussionId: discussionId, postId: draft.postId, subject: subject, text: body,
        keepNames: kept.map(\.name), paths: added)
    else { return nil }
    if !result.messages.isEmpty {
      presenter.toast(result.messages.joined(separator: "\n"), kind: result.ok ? .success : .error)
    }
    return result.ok ? result : nil
  }

  func cancelUpload() async {
    try? await client.cancelTransfer(discussionId: discussionId)
  }
}
