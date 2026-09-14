import Foundation
import Observation

@MainActor
@Observable
final class AssignmentDetailModel {
  private(set) var result: AssignmentDetailResult?
  /// 移除、沿用、送出評分都沒有進度框：這一顆就是「按下去真的有事情在跑」的證據，也擋住第二下。
  private(set) var writing = false
  var web: WebPage?
  var submit: AssignmentSubmitModel?

  let course: CourseRef
  let assignId: Int64
  let name: String
  let client: AssignmentClient
  let moodle: CourseMoodleClient
  @ObservationIgnored private let onChanged: () -> Void

  init(
    client: AssignmentClient, moodle: CourseMoodleClient, course: CourseRef, assignId: Int64, name: String,
    onChanged: @escaping () -> Void
  ) {
    self.client = client
    self.moodle = moodle
    self.course = course
    self.assignId = assignId
    self.name = name
    self.onChanged = onChanged
  }

  var detail: AssignmentDetail? { result?.detail }

  func load(refresh: Bool) async {
    let fetched = try? await client.detail(courseId: course.courseId, assignId: assignId, refresh: refresh)
    result = fetched ?? AssignmentDetailResult(error: L10n.unknownError, signedIn: true)
  }

  func submitForGrading(acceptStatement: Bool, presenter: UiPresenter) async {
    await write(presenter) { client, id in
      try await client.submitForGrading(assignId: id, acceptStatement: acceptStatement)
    }
  }

  func removeSubmission(presenter: UiPresenter) async {
    await write(presenter) { client, id in try await client.removeSubmission(assignId: id) }
  }

  func copyPrevious(presenter: UiPresenter) async {
    await write(presenter) { client, id in try await client.copyPrevious(assignId: id) }
  }

  /// 寫入之後的共同收尾：先講結果，再照伺服器的新狀態重畫，清單那一列也跟著換。
  func apply(_ outcome: AssignWriteResult, presenter: UiPresenter) {
    if !outcome.messages.isEmpty {
      presenter.toast(outcome.messages.joined(separator: "\n"))
    }
    if let detail = outcome.detail {
      result = AssignmentDetailResult(detail: detail, signedIn: result?.signedIn ?? true)
      onChanged()
    }
  }

  func openInWeb() async {
    guard let link = try? await client.webLink(assignId: assignId), let url = URL(string: link.url) else { return }
    web = WebPage(
      title: detail?.name ?? name, url: url, fallbackURL: link.fallbackUrl.flatMap(URL.init(string:)))
  }

  func openSubmit() async {
    guard let state = try? await client.openSubmit(assignId: assignId) else { return }
    submit = AssignmentSubmitModel(
      client: client, moodle: moodle, course: course, assignId: assignId, state: state,
      clockSkew: detail?.clockSkewSeconds ?? 0)
  }

  private func write(
    _ presenter: UiPresenter, _ call: (AssignmentClient, Int64) async throws -> AssignWriteResult
  ) async {
    guard !writing else { return }
    writing = true
    defer { writing = false }
    guard let outcome = try? await call(client, assignId) else { return }
    apply(outcome, presenter: presenter)
  }
}
