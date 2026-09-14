import Observation

@MainActor
@Observable
final class SimulationModel {
  private(set) var state: SimulationState
  private(set) var busy = false

  let client: SimulationClient

  init(client: SimulationClient, state: SimulationState) {
    self.client = client
    self.state = state
  }

  var draftId: String { state.id }

  /// 搜尋頁回來之後重畫：那一頁加的課已經存進草稿了。
  func reload() async {
    if let fetched = try? await client.draft(id: draftId) { state = fetched }
  }

  func remove(courseId: String) async {
    busy = true
    defer { busy = false }
    if let fetched = try? await client.removeCourse(draftId: draftId, courseId: courseId) { state = fetched }
  }
}
