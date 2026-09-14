import Flutter
import WebKit

/// 核心驅動的 WKWebView 們。WebSession 的事件在這裡轉成 Pigeon 送回 Dart，`Web/` 不認得 Pigeon。
@MainActor
final class CoreWebSessions {
  private let events: TatWebSessionEvents
  private let presenter: UiPresenter
  private var sessions: [Int64: WebSession] = [:]
  /// App 內瀏覽器的 WebView 由畫面自己持有，這裡只借來跑核心的 JavaScript。
  private var attached: [Int64: AttachedWebView] = [:]

  private struct AttachedWebView {
    weak var webView: WKWebView?
  }

  init(messenger: FlutterBinaryMessenger, presenter: UiPresenter) {
    events = TatWebSessionEvents(binaryMessenger: messenger)
    self.presenter = presenter
  }

  func open(_ request: WebSessionRequest) {
    let id = request.sessionId
    let events = events
    let session = WebSession(
      id: id,
      url: request.url,
      title: request.title,
      progressMessage: request.progressMessage,
      interceptSchemes: request.interceptSchemes,
      callbacks: .init(
        loadStop: { events.onLoadStop(sessionId: id, url: $0) { _ in } },
        loadError: { events.onLoadError(sessionId: id, description: $0) { _ in } },
        intercepted: { events.onIntercepted(sessionId: id, url: $0) { _ in } },
        dismissed: { [weak self] in
          self?.sessions[id] = nil
          events.onDismissed(sessionId: id) { _ in }
        }
      )
    )
    sessions[id] = session
    session.start()
    if request.visible { presenter.webSession = session }
  }

  func attach(_ id: Int64, webView: WKWebView) {
    attached[id] = AttachedWebView(webView: webView)
  }

  func detach(_ id: Int64) {
    attached[id] = nil
  }

  func evaluate(_ id: Int64, _ source: String, completion: @escaping (Any?) -> Void) {
    if let session = sessions[id] { return session.evaluateJavaScript(source, completion: completion) }
    guard let webView = attached[id]?.webView else { return completion(nil) }
    // undefined、DOM 節點這類 WebKit 回錯誤的型別當成 null，同 WebSession。
    webView.evaluateJavaScript(source) { value, error in completion(error == nil ? value : nil) }
  }

  func html(_ id: Int64, completion: @escaping (String?) -> Void) {
    if let session = sessions[id] { return session.html(completion: completion) }
    evaluate(id, "document.documentElement.outerHTML") { completion($0 as? String) }
  }

  func load(_ id: Int64, url: String) {
    if let session = sessions[id] { return session.load(url) }
    guard let webView = attached[id]?.webView, let target = URL(string: url) else { return }
    webView.load(URLRequest(url: target))
  }

  func setProgress(_ id: Int64, message: String?) {
    sessions[id]?.setProgress(message)
  }

  func close(_ id: Int64) {
    guard let session = sessions.removeValue(forKey: id) else { return }
    session.close()
    if presenter.webSession?.id == id { presenter.webSession = nil }
  }
}
