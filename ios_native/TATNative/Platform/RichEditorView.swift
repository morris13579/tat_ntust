import SwiftUI
import WebKit

/// 所見即所得編輯器的遙控器。頁面拿它下指令、取內容，編輯器本身不知道那些內容是什麼意思。
@MainActor
final class RichEditorController {
  fileprivate weak var webView: WKWebView?

  /// 工具列送得出去的指令，字面值與 `assets/editor/editor.js` 的那一份一致。
  enum Command: String, CaseIterable {
    case bold, italic, underline, strikeThrough
    case paragraph = "p"
    case heading3 = "h3"
    case heading4 = "h4"
    case heading5 = "h5"
    case unorderedList = "ul"
    case orderedList = "ol"
    case removeFormat
  }

  func exec(_ command: Command) {
    webView?.evaluateJavaScript("window.__tatEditor.exec(\"\(command.rawValue)\");")
  }

  func setSourceMode(_ on: Bool) {
    webView?.evaluateJavaScript("window.__tatEditor.setSourceMode(\(on));")
  }

  /// 編輯器現在的內容；還沒接上時回 nil。**呼叫端不可以把 nil 當成空內容送出去**：那會把整篇貼文清掉。
  func content() async -> String? {
    guard let webView else { return nil }
    return try? await webView.evaluateJavaScript("window.__tatEditor.getContent();") as? String
  }

  func blur() {
    webView?.endEditing(true)
  }
}

/// `assets/editor/editor.html` 那一頁的殼：HTML 進、HTML 出，不認識 Moodle、不改網址。
/// 頁面寫給 flutter_inappwebview 的 `callHandler`，這裡補一個同名的物件轉給 WebKit 的訊息通道。
struct RichEditorView: UIViewRepresentable {
  let pageURL: URL
  /// 放入初始內容的那一行 JavaScript，由核心逃脫過。
  let contentScript: String
  let controller: RichEditorController
  var onReady: () -> Void
  var onInput: () -> Void
  var onState: (Set<String>) -> Void
  var onFailed: () -> Void

  /// 從載入到握手的等待上限。超過就當成載不起來。
  private static let readyTimeout: Duration = .seconds(10)

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    let shim = """
      window.flutter_inappwebview = { callHandler: function (name, arg) {
        window.webkit.messageHandlers.tatEditor.postMessage({ name: name, arg: arg === undefined ? null : arg });
      } };
      """
    configuration.userContentController.addUserScript(
      WKUserScript(source: shim, injectionTime: .atDocumentStart, forMainFrameOnly: true))
    configuration.userContentController.add(context.coordinator, name: "tatEditor")
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.isOpaque = false
    view.backgroundColor = .clear
    view.scrollView.backgroundColor = .clear
    view.scrollView.showsVerticalScrollIndicator = false
    view.scrollView.showsHorizontalScrollIndicator = false
    view.navigationDelegate = context.coordinator
    controller.webView = view
    context.coordinator.startTimeout()
    view.loadFileURL(pageURL, allowingReadAccessTo: pageURL.deletingLastPathComponent())
    return view
  }

  func updateUIView(_ view: WKWebView, context: Context) {
    context.coordinator.parent = self
    context.coordinator.pushTheme(dark: context.environment.colorScheme == .dark)
  }

  static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
    view.configuration.userContentController.removeScriptMessageHandler(forName: "tatEditor")
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  @MainActor
  final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    var parent: RichEditorView
    private var ready = false
    private var failed = false
    private var pushedDark: Bool?

    init(parent: RichEditorView) {
      self.parent = parent
    }

    func startTimeout() {
      Task { [weak self] in
        try? await Task.sleep(for: RichEditorView.readyTimeout)
        self?.fail()
      }
    }

    /// 底色畫在後面，字色寫在頁面的 CSS 裡；系統中途換深色時不重推就會變成同色不可讀。
    func pushTheme(dark: Bool) {
      guard ready, pushedDark != dark else { return }
      pushedDark = dark
      parent.controller.webView?.evaluateJavaScript(
        "document.documentElement.setAttribute(\"data-theme\", \"\(dark ? "dark" : "light")\");")
    }

    nonisolated func userContentController(
      _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
      let body = message.body as? [String: Any]
      let name = body?["name"] as? String
      let arg = body?["arg"]
      MainActor.assumeIsolated { handle(name, arg) }
    }

    private func handle(_ name: String?, _ arg: Any?) {
      switch name {
      case "tatEditorReady":
        guard !ready, !failed else { return }
        ready = true
        let webView = parent.controller.webView
        pushTheme(dark: webView?.traitCollection.userInterfaceStyle == .dark)
        webView?.evaluateJavaScript(parent.contentScript) { [weak self] _, _ in
          Task { @MainActor in self?.parent.onReady() }
        }
      case "tatEditorInput":
        parent.onInput()
      case "tatEditorState":
        parent.onState(Self.activeFormats(arg))
      default:
        break
      }
    }

    /// 橋接回報的 `{"bold":true,…,"block":"h3"}` → 目前生效的格式。形狀不對就當成什麼都沒生效。
    private static func activeFormats(_ raw: Any?) -> Set<String> {
      guard let map = raw as? [String: Any] else { return [] }
      let known = Set(RichEditorController.Command.allCases.map(\.rawValue))
      var active = Set<String>()
      for (key, value) in map {
        if key == "block", let block = value as? String, known.contains(block) {
          active.insert(block)
        } else if (value as? Bool) == true, known.contains(key) {
          active.insert(key)
        }
      }
      return active
    }

    private func fail() {
      guard !ready, !failed else { return }
      failed = true
      parent.onFailed()
    }

    /// 只放行資源本身那一次：貼文裡的連結被點到就會把整個編輯器導航走，還沒存的草稿跟著消失。
    func webView(
      _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
      let url = navigationAction.request.url
      let isPage = url?.isFileURL == true && url?.lastPathComponent == parent.pageURL.lastPathComponent
      decisionHandler(isPage ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      fail()
    }

    func webView(
      _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
    ) {
      fail()
    }
  }
}
