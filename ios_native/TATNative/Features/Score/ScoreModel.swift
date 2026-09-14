import Observation

@MainActor
@Observable
final class ScoreModel {
  enum Phase {
    case loading, loaded, notSignedIn, failed
  }

  private(set) var phase: Phase = .loading
  private(set) var semesters: [ScoreSemester] = []
  private(set) var isBusy = false
  /// 目前看的學期，「115-1」。
  var selection: String?
  /// 每載入一次就加一，清單用它重播進場動畫。
  private(set) var loadCount = 0

  let client: ScoreClient
  private var started = false

  init(client: ScoreClient) {
    self.client = client
  }

  func start() async {
    guard !started else { return }
    started = true
    await load(refresh: false)
  }

  func refresh() async {
    await load(refresh: true)
  }

  private func load(refresh: Bool) async {
    isBusy = true
    defer { isBusy = false }
    if semesters.isEmpty { phase = .loading }
    guard let report = try? await client.load(refresh: refresh) else {
      if semesters.isEmpty { phase = .failed }
      return
    }
    switch report.state {
    case .notSignedIn:
      semesters = []
      phase = .notSignedIn
    case .ok, .failed:
      // 抓不到新的時 Dart 會把存著的那一份一起回來；兩者都沒有才是錯誤頁。
      if report.state == .failed, report.semesters.isEmpty {
        if semesters.isEmpty { phase = .failed }
        return
      }
      let current = selection
      semesters = report.semesters
      selection =
        semesters.contains { $0.semester == current } ? current : semesters.first?.semester
      phase = .loaded
      loadCount += 1
    }
  }
}
