import Foundation

/// Dart → Swift：`TatCoreUiApi` 的實作，對應 Flutter 版的 `TaskUiDelegate`。
///
/// Pigeon 在主執行緒上呼叫，但協定不是 MainActor 隔離的，所以每一支都是 nonisolated
/// 再明確跳回 MainActor。
@MainActor
final class CoreUiHost: TatCoreUiApi {
  private let presenter: UiPresenter
  private let webSessions: CoreWebSessions

  init(presenter: UiPresenter, webSessions: CoreWebSessions) {
    self.presenter = presenter
    self.webSessions = webSessions
  }

  nonisolated func beginProgress(message: String) throws -> Int64 {
    MainActor.assumeIsolated { presenter.beginProgress(message) }
  }

  nonisolated func dismissProgress(handle: Int64) throws {
    MainActor.assumeIsolated { presenter.dismissProgress(handle) }
  }

  nonisolated func confirmRetry(
    request: ErrorDialogRequest,
    completion: @escaping (Result<RetryChoice, Error>) -> Void
  ) {
    Task { @MainActor in
      presenter.ask(request) { completion(.success($0)) }
    }
  }

  nonisolated func toast(message: String) throws {
    Task { @MainActor in presenter.toast(message) }
  }

  nonisolated func chooseOne(
    title: String, options: [ChooseOption],
    completion: @escaping (Result<String?, Error>) -> Void
  ) {
    Task { @MainActor in
      presenter.choose(title: title, options: options) { completion(.success($0)) }
    }
  }

  nonisolated func chooseSemester(
    allowNull: Bool, completion: @escaping (Result<String?, Error>) -> Void
  ) {
    Task { @MainActor in
      presenter.chooseSemester(allowNull: allowNull) { completion(.success($0)) }
    }
  }

  nonisolated func openLoginScreen(completion: @escaping (Result<Void, Error>) -> Void) {
    // 和 Flutter 版的 RouteUtils.toLoginScreen 一樣，等登入頁關掉才回答。
    Task { @MainActor in
      presenter.requestLogin { completion(.success(())) }
    }
  }

  nonisolated func webCookies(
    url: String, completion: @escaping (Result<[WebCookie], Error>) -> Void
  ) {
    Task { @MainActor in
      WebHost.cookies(url: url) { completion(.success($0)) }
    }
  }

  nonisolated func loadPage(
    request: PageLoadRequest, completion: @escaping (Result<PageLoadResult, Error>) -> Void
  ) {
    Task { @MainActor in
      WebHost.loadPage(request) { completion(.success($0)) }
    }
  }

  // MARK: - 核心驅動的 WebView

  nonisolated func openWebSession(request: WebSessionRequest) throws {
    MainActor.assumeIsolated { webSessions.open(request) }
  }

  nonisolated func evaluateJavascript(
    sessionId: Int64, source: String, completion: @escaping (Result<Any?, Error>) -> Void
  ) {
    Task { @MainActor in
      webSessions.evaluate(sessionId, source) { completion(.success($0)) }
    }
  }

  nonisolated func webSessionHtml(
    sessionId: Int64, completion: @escaping (Result<String?, Error>) -> Void
  ) {
    Task { @MainActor in
      webSessions.html(sessionId) { completion(.success($0)) }
    }
  }

  nonisolated func loadWebSessionUrl(sessionId: Int64, url: String) throws {
    MainActor.assumeIsolated { webSessions.load(sessionId, url: url) }
  }

  nonisolated func setWebSessionProgress(sessionId: Int64, message: String?) throws {
    MainActor.assumeIsolated { webSessions.setProgress(sessionId, message: message) }
  }

  nonisolated func closeWebSession(sessionId: Int64) throws {
    MainActor.assumeIsolated { webSessions.close(sessionId) }
  }
}
