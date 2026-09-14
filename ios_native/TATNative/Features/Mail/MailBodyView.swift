import SwiftUI
import WebKit

/// 信件內文。寄件者的 HTML 是整個 App 唯一不是我們排版的內容，交給 WebKit 畫，規則照 `MailDetailPage`：
/// 遠端資源預設不載入（相當比例是追蹤像素）、信裡的 JavaScript 不跑、深色模式蓋掉核心標出來的顏色。
/// 比螢幕寬的信整封縮到剛好，高度跟著內容走，捲動交給外面那一頁。
struct MailBodyView: UIViewRepresentable {
  let html: String
  let allowRemote: Bool
  @Binding var height: CGFloat
  let openURL: (URL) -> Void

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false
    // 放行遠端圖片時也不留 cookie：寄件者的追蹤不該跟著 App 走。
    configuration.websiteDataStore = .nonPersistent()
    let scripts = configuration.userContentController
    scripts.addUserScript(
      WKUserScript(source: Self.measureScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
    scripts.add(context.coordinator, contentWorld: .defaultClient, name: Self.handler)
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.isOpaque = false
    view.backgroundColor = .clear
    view.scrollView.backgroundColor = .clear
    view.scrollView.isScrollEnabled = false
    // 長按連結的預覽會真的去載那一頁。
    view.allowsLinkPreview = false
    view.navigationDelegate = context.coordinator
    context.coordinator.webView = view
    return view
  }

  func updateUIView(_ view: WKWebView, context: Context) {
    context.coordinator.parent = self
    context.coordinator.render(html: html, allowRemote: allowRemote)
  }

  static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
    view.configuration.userContentController.removeScriptMessageHandler(forName: handler, contentWorld: .defaultClient)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  private static let handler = "tatMail"

  /// 比版面寬的信把 viewport 撐到內容的寬度，WebKit 會整頁縮到剛好；高度用 CSS 像素回報，換算在原生這一側。
  private static let measureScript = """
    (function () {
      var meta = document.querySelector('meta[name=viewport]');
      function report() {
        if (!document.body) return;
        var wide = document.documentElement.scrollWidth;
        if (meta && wide > window.innerWidth + 1) meta.setAttribute('content', 'width=' + wide);
        window.webkit.messageHandlers.tatMail.postMessage({
          height: document.body.scrollHeight, width: window.innerWidth
        });
      }
      if (window.ResizeObserver && document.body) new ResizeObserver(report).observe(document.body);
      window.addEventListener('load', report);
      report();
    })();
    """

  private static func document(_ body: String) -> String {
    """
    <!doctype html><html><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="light dark">
    <style>
    html, body { margin: 0; padding: 0; background: transparent; }
    body { display: flow-root; font: -apple-system-body; line-height: 1.5; color: CanvasText;
      overflow-wrap: anywhere; -webkit-text-size-adjust: 100%; }
    img { max-width: 100%; height: auto; }
    pre { white-space: pre-wrap; }
    a { color: #405F90; }
    @media (prefers-color-scheme: dark) {
      a { color: #A9C7FF; }
      [data-tat-neutral] { color: inherit !important; background: none !important; }
    }
    </style></head><body>\(body)</body></html>
    """
  }

  @MainActor private static var blockRemoteRules: WKContentRuleList?

  private static func blockRemote() async -> WKContentRuleList? {
    if let blockRemoteRules { return blockRemoteRules }
    let source = #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#
    let compiled = try? await WKContentRuleListStore.default().compileContentRuleList(
      forIdentifier: "tat-mail-block-remote", encodedContentRuleList: source)
    blockRemoteRules = compiled
    return compiled
  }

  @MainActor
  final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var parent: MailBodyView
    weak var webView: WKWebView?
    private var rendered: (html: String, allowRemote: Bool)?
    private var generation = 0

    init(parent: MailBodyView) {
      self.parent = parent
    }

    func render(html: String, allowRemote: Bool) {
      if let rendered, rendered.allowRemote == allowRemote, rendered.html == html { return }
      rendered = (html, allowRemote)
      generation += 1
      let current = generation
      Task {
        guard let webView else { return }
        let scripts = webView.configuration.userContentController
        var rules: WKContentRuleList?
        if !allowRemote {
          // 規則編不出來就不載：寧可空白，也不要在使用者沒同意時對外連線。
          rules = await MailBodyView.blockRemote()
          guard rules != nil else { return }
        }
        guard current == generation else { return }
        scripts.removeAllContentRuleLists()
        if let rules { scripts.add(rules) }
        webView.loadHTMLString(MailBodyView.document(html), baseURL: nil)
      }
    }

    nonisolated func userContentController(
      _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
      let body = message.body as? [String: Any]
      let height = (body?["height"] as? NSNumber)?.doubleValue ?? 0
      let width = (body?["width"] as? NSNumber)?.doubleValue ?? 0
      MainActor.assumeIsolated { resize(cssHeight: height, cssWidth: width) }
    }

    private func resize(cssHeight: Double, cssWidth: Double) {
      guard let webView, cssHeight > 0, cssWidth > 0, webView.bounds.width > 0 else { return }
      let next = ceil(cssHeight * webView.bounds.width / cssWidth)
      if abs(next - parent.height) > 1 { parent.height = next }
    }

    /// 只放行自己載入的那一頁與內嵌的 data:；信裡的連結交給畫面決定怎麼開。
    func webView(
      _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
      let url = navigationAction.request.url
      if navigationAction.navigationType == .linkActivated, let url {
        decisionHandler(.cancel)
        parent.openURL(url)
        return
      }
      decisionHandler(url?.scheme == "about" || url?.scheme == "data" ? .allow : .cancel)
    }
  }
}
