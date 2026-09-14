import Foundation
import Observation

enum MailField: Hashable {
  case to, cc, bcc
}

/// 寫信。收成籤時的切開、去重與驗格式都在核心，這裡只管畫面上還在打的字、附件與編輯器。
@MainActor
@Observable
final class MailComposeModel {
  let client: MailClient
  let kind: MailComposeKind
  let ref: String
  private(set) var start: MailComposeStart?
  private(set) var chips: [MailField: [MailRecipient]] = [:]
  private(set) var texts: [MailField: String] = [:]
  var subject = ""
  var focus: MailField?
  var showCopyFields = false
  private(set) var attachments: [String] = []
  private(set) var suggestions: [MailContactRow] = []
  private(set) var suggestField: MailField?
  private(set) var editorReady = false
  private(set) var editorFailed = false
  /// 使用者真的動過內文：回覆帶進來的引言不算。
  private(set) var edited = false
  private(set) var sending = false
  private(set) var sourceMode = false
  /// 重試時換一個，讓編輯器整個重建。
  private(set) var editorGeneration = 0
  var activeFormats: Set<String> = []
  @ObservationIgnored let editor = RichEditorController()
  @ObservationIgnored private var suggestTask: Task<Void, Never>?
  /// 收籤一次一趟：打字很快時前一趟還沒回來，後一趟拿到的既有清單會少一顆。
  @ObservationIgnored private var adding: Task<Void, Never>?

  init(client: MailClient, kind: MailComposeKind, ref: String) {
    self.client = client
    self.kind = kind
    self.ref = ref
  }

  func begin() async {
    guard start == nil, let start = try? await client.startCompose(kind: kind, ref: ref) else { return }
    self.start = start
    chips[.to] = start.to
    subject = start.subject
  }

  func recipients(_ field: MailField) -> [MailRecipient] {
    chips[field] ?? []
  }

  func text(_ field: MailField) -> String {
    texts[field] ?? ""
  }

  /// 有沒有打過東西。空白不算——只點進來又退出去不該被問。
  var hasDraft: Bool {
    chips.values.contains { !$0.isEmpty }
      || texts.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      || !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty || edited
  }

  /// 分隔符一出現就把前面那一截收成籤，後面還在打的留在欄位裡，照 `MailRecipientField._onTextChanged`。
  func setText(_ value: String, for field: MailField) {
    guard let cut = value.lastIndex(where: { $0 == "," || $0 == ";" || $0 == "\n" }) else {
      texts[field] = value
      scheduleSuggest(value, for: field)
      return
    }
    texts[field] = String(value[value.index(after: cut)...])
    let head = String(value[..<cut])
    Task { await add(head, to: field) }
  }

  /// 按下換行或離開欄位時，把還在打的那一截收成籤。
  func commit(_ field: MailField) async {
    let raw = text(field)
    guard !raw.isEmpty else { return }
    texts[field] = ""
    await add(raw, to: field)
  }

  func pick(_ contact: MailContactRow, for field: MailField) async {
    texts[field] = ""
    await add(contact.email, to: field)
  }

  func remove(at index: Int, from field: MailField) {
    guard var list = chips[field], list.indices.contains(index) else { return }
    list.remove(at: index)
    chips[field] = list
  }

  /// 空欄位按退格拿掉最後一顆：不然刪掉打錯的那一顆要先瞄準一個小叉。
  func removeLast(from field: MailField) {
    guard var list = chips[field], !list.isEmpty else { return }
    list.removeLast()
    chips[field] = list
  }

  private func add(_ raw: String, to field: MailField) async {
    clearSuggestions()
    guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let previous = adding
    let task = Task {
      await previous?.value
      guard let next = try? await client.addRecipients(existing: recipients(field).map(\.address), raw: raw)
      else { return }
      chips[field] = next
    }
    adding = task
    await task.value
  }

  /// 打完字等一下才查：每一鍵都查會讓快速輸入時建議清單一直跳。
  private func scheduleSuggest(_ query: String, for field: MailField) {
    suggestTask?.cancel()
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      suggestions = []
      suggestField = nil
      return
    }
    suggestTask = Task {
      try? await Task.sleep(for: .milliseconds(180))
      guard !Task.isCancelled,
        let hits = try? await client.suggest(query: query, taken: recipients(field).map(\.address)),
        !Task.isCancelled, text(field) == query
      else { return }
      suggestField = field
      suggestions = hits
    }
  }

  func clearSuggestions() {
    suggestTask?.cancel()
    suggestions = []
    suggestField = nil
  }

  func addAttachments(_ paths: [String], presenter: UiPresenter) async {
    guard !paths.isEmpty, let check = try? await client.checkAttachments(existing: attachments, picked: paths)
    else { return }
    attachments += check.accepted
    if let error = check.error { presenter.toast(error, kind: .error) }
  }

  func removeAttachment(_ path: String) {
    attachments.removeAll { $0 == path }
  }

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

  /// 排進寄件匣就回傳結果，頁面關掉；沒收下一律留在原地，打好的字一個都不動。
  func send(presenter: UiPresenter) async -> MailSendResult? {
    guard !sending, editorReady else { return nil }
    sending = true
    defer { sending = false }
    // 拿不到內容時是 nil，由核心退回帶進來的引言：當成空字串會把整篇清掉。
    let html = await editor.content()
    let request = MailSendRequest(
      to: recipients(.to).map(\.address), cc: recipients(.cc).map(\.address), bcc: recipients(.bcc).map(\.address),
      pendingTo: text(.to), pendingCc: text(.cc), pendingBcc: text(.bcc), subject: subject, html: html,
      attachments: attachments)
    guard let result = try? await client.send(request) else {
      presenter.toast(L10n.mailSendFailed, kind: .error)
      return nil
    }
    if let error = result.error {
      presenter.toast(error, kind: .error)
      return nil
    }
    return result
  }
}
