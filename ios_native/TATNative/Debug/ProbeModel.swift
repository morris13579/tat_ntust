import Foundation
import Observation

/// 探針畫面的狀態。正式主畫面做出來之後連同 ProbeView 一起刪掉。
@MainActor
@Observable
final class ProbeModel {
  enum LoadState<T> {
    case idle
    case running
    case ok(T)
    case failed(String)
  }

  private(set) var status: LoadState<CoreStatus> = .idle
  private(set) var courseTable: LoadState<CoreResult<CourseTable>> = .idle
  private(set) var score: LoadState<CoreResult<ScoreSummary>> = .idle
  private(set) var webHostProbe: LoadState<String> = .idle
  private(set) var interactiveSignIn: LoadState<String> = .idle

  private let core: CoreClient

  init(core: CoreClient) {
    self.core = core
  }

  func loadStatus() async {
    status = .running
    do { status = .ok(try await core.status()) } catch { status = .failed(describe(error)) }
  }

  func loadCourseTable() async {
    courseTable = .running
    do { courseTable = .ok(try await core.courseTable()) } catch { courseTable = .failed(describe(error)) }
  }

  func loadScore() async {
    score = .running
    do { score = .ok(try await core.score()) } catch { score = .failed(describe(error)) }
  }

  /// 走核心的 InteractiveLoginGateway 開可見的登入頁。帳密有效時 headless 登入就會成功，
  /// 正常流程看不到這一頁，要測只能直接開。
  func signIn(moodle: Bool) async {
    interactiveSignIn = .running
    do {
      interactiveSignIn = .ok(try await core.debugInteractiveSignIn(moodle: moodle))
    } catch {
      interactiveSignIn = .failed(describe(error))
    }
  }

  /// 不經過 Dart，用成績頁的真實判準直接打一次 WebHost。沒有 session 時預期 redirectedToLogin。
  func probeWebHost() {
    webHostProbe = .running
    let request = PageLoadRequest(
      url: "https://stuinfosys.ntust.edu.tw/StuScoreQueryServ/StuScoreQuery/DisplayAll",
      completeWhenHtmlContainsAll: ["box-content alerts", "<tbody"],
      failWhenUrlContainsAny: ["https://ssoam2.ntust.edu.tw/account/login"],
      timeoutSeconds: 20
    )
    WebHost.loadPage(request) { result in
      Task { @MainActor in
        self.webHostProbe = .ok("\(result.outcome) html=\(result.html?.count ?? 0) \(result.detail ?? "")")
      }
    }
  }

  private func describe(_ error: Error) -> String {
    (error as? PigeonError)?.message ?? "\(error)"
  }
}
