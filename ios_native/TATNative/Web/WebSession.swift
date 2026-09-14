import UIKit
import WebKit

/// 一個由核心驅動的 WKWebView：跑 JavaScript、回報每一頁載完。headless 的掛在視窗底下看不到，
/// 可見的由 `WebLoginSheet` 放上畫面。這裡不認得 Pigeon，事件交給 `Callbacks`。
///
/// **一律用 `WKWebsiteDataStore.default()`**：登入寫進去的 cookie 就在這一份，`WebHost` 讀的也是它。
@MainActor
@Observable
final class WebSession: Identifiable {
  struct Callbacks {
    var loadStop: (String?) -> Void
    var loadError: (String) -> Void
    var intercepted: (String) -> Void
    var dismissed: () -> Void
  }

  let id: Int64
  let title: String
  private(set) var progressMessage: String?

  @ObservationIgnored let webView: WKWebView
  @ObservationIgnored private let initialURL: URL?
  @ObservationIgnored private let callbacks: Callbacks
  @ObservationIgnored private let navigation: NavigationDelegate
  @ObservationIgnored private var isClosed = false

  init(
    id: Int64, url: String, title: String, progressMessage: String?,
    interceptSchemes: [String], callbacks: Callbacks
  ) {
    self.id = id
    self.title = title
    self.progressMessage = progressMessage
    self.callbacks = callbacks
    initialURL = URL(string: url)
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    // 給真實尺寸：接近零的 viewport 會讓 Turnstile 與推進轉址鏈的 form.submit() 延後或不跑。
    webView = WKWebView(
      frame: CGRect(x: 0, y: 0, width: 412, height: 892), configuration: configuration)
    navigation = NavigationDelegate(interceptSchemes: Set(interceptSchemes.map { $0.lowercased() }))
    webView.navigationDelegate = navigation
    navigation.session = self
  }

  /// 先掛在視窗底下再開始載入，可見的也一樣：離屏的 WKWebView 跑 JavaScript 不可靠，
  /// 而 sheet 還沒出來時第一頁就可能已經載完。
  func start() {
    if let window = Self.keyWindow {
      webView.alpha = 0
      webView.isUserInteractionEnabled = false
      window.insertSubview(webView, at: 0)
    }
    if let initialURL { webView.load(URLRequest(url: initialURL)) }
  }

  func didMoveOnScreen() {
    webView.alpha = 1
    webView.isUserInteractionEnabled = true
  }

  func evaluateJavaScript(_ source: String, completion: @escaping (Any?) -> Void) {
    guard !isClosed else { return completion(nil) }
    webView.evaluateJavaScript(source) { value, error in
      // undefined、DOM 節點這類 WebKit 回錯誤的型別，和 flutter_inappwebview 一樣當成 null。
      completion(error == nil ? value : nil)
    }
  }

  func html(completion: @escaping (String?) -> Void) {
    evaluateJavaScript("document.documentElement.outerHTML") { completion($0 as? String) }
  }

  func load(_ url: String) {
    guard !isClosed, let url = URL(string: url) else { return }
    webView.load(URLRequest(url: url))
  }

  func setProgress(_ message: String?) {
    progressMessage = message
  }

  /// 核心要求關掉。不送 dismissed：那個事件只代表使用者自己關掉。
  func close() {
    guard !isClosed else { return }
    isClosed = true
    webView.navigationDelegate = nil
    webView.stopLoading()
    // 已經放上 sheet 的留給 sheet 收，現在拿掉的話關閉動畫裡會是一片空白。
    if webView.alpha == 0 { webView.removeFromSuperview() }
  }

  func dismissedByUser() {
    guard !isClosed else { return }
    close()
    callbacks.dismissed()
  }

  fileprivate func loadStopped(_ url: String?) {
    if !isClosed { callbacks.loadStop(url) }
  }

  fileprivate func loadFailed(_ description: String) {
    if !isClosed { callbacks.loadError(description) }
  }

  fileprivate func intercepted(_ url: String) {
    if !isClosed { callbacks.intercepted(url) }
  }

  private static var keyWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
  }
}

@MainActor
private final class NavigationDelegate: NSObject, WKNavigationDelegate {
  weak var session: WebSession?
  private let interceptSchemes: Set<String>

  init(interceptSchemes: Set<String>) {
    self.interceptSchemes = interceptSchemes
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction
  ) async -> WKNavigationActionPolicy {
    guard let url = navigationAction.request.url,
      let scheme = url.scheme?.lowercased(),
      interceptSchemes.contains(scheme)
    else { return .allow }
    session?.intercepted(url.absoluteString)
    return .cancel
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    session?.loadStopped(webView.url?.absoluteString)
  }

  // 與 flutter_inappwebview 一致：兩種失敗都回報，連被新導航打斷的 NSURLErrorCancelled 也算。
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    session?.loadFailed(error.localizedDescription)
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    session?.loadFailed(error.localizedDescription)
  }
}
