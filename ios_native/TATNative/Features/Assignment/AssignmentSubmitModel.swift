import Foundation
import Observation

@MainActor
@Observable
final class AssignmentSubmitModel {
  private(set) var state: SubmitState
  /// 輸入框自己的那一份：核心回來的字不可以蓋回去，使用者可能已經又打了幾個字。
  var text: String
  private(set) var saving = false
  private(set) var starting = false

  let course: CourseRef
  let assignId: Int64
  let clockSkew: Int64
  let client: AssignmentClient
  let moodle: CourseMoodleClient

  init(
    client: AssignmentClient, moodle: CourseMoodleClient, course: CourseRef, assignId: Int64,
    state: SubmitState, clockSkew: Int64
  ) {
    self.client = client
    self.moodle = moodle
    self.course = course
    self.assignId = assignId
    self.state = state
    self.clockSkew = clockSkew
    text = state.text
  }

  var transferKey: String { "assign-\(assignId)" }

  /// 寫入進行中不給走：取消送不到 save_submission，離開只會讓這一趟的結果沒有人接。
  var busy: Bool { saving || starting }

  func textChanged() async {
    if let next = try? await client.setText(assignId: assignId, text: text) { state = next }
  }

  func setAccepted(_ accepted: Bool, presenter: UiPresenter) async {
    if let next = try? await client.setAccepted(assignId: assignId, accepted: accepted) {
      show(next, presenter: presenter)
    }
  }

  func add(_ urls: [URL], presenter: UiPresenter) async {
    let paths = PickedFiles.copy(urls)
    guard !paths.isEmpty, let next = try? await client.addFiles(assignId: assignId, paths: paths) else { return }
    show(next, presenter: presenter)
  }

  func toggleFile(_ index: Int, presenter: UiPresenter) async {
    if let next = try? await client.toggleFile(assignId: assignId, index: Int64(index)) {
      show(next, presenter: presenter)
    }
  }

  func saveConfirmation() async -> String? {
    (try? await client.saveConfirmation(assignId: assignId)) ?? nil
  }

  /// 回傳非 nil 且 `close` 為真：伺服器被寫過了，要回詳情頁。
  func save(transfers: TransferCenter, presenter: UiPresenter) async -> SubmitOutcome? {
    guard !busy else { return nil }
    saving = true
    transfers.clear(transferKey)
    defer {
      saving = false
      transfers.clear(transferKey)
    }
    guard let outcome = try? await client.save(assignId: assignId) else { return nil }
    if !outcome.messages.isEmpty {
      presenter.toast(outcome.messages.joined(separator: "\n"), kind: outcome.close ? .success : .error)
    }
    if let next = outcome.state { state = next }
    return outcome
  }

  func cancel() async {
    try? await client.cancelSubmit(assignId: assignId)
  }

  func startConfirmation() async -> String? {
    try? await client.startConfirmation(assignId: assignId)
  }

  func start(presenter: UiPresenter) async {
    guard !busy else { return }
    starting = true
    defer { starting = false }
    if let next = try? await client.start(assignId: assignId) { show(next, presenter: presenter) }
  }

  func close() async -> AssignWriteResult? {
    try? await client.closeSubmit(assignId: assignId)
  }

  private func show(_ next: SubmitState, presenter: UiPresenter) {
    state = next
    if !next.messages.isEmpty {
      presenter.toast(next.messages.joined(separator: "\n"), kind: .error)
    }
  }
}
