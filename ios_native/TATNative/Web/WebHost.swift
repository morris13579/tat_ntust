import Foundation
import UIKit
import WebKit

/// 平台 WebView 這一側。Dart 核心透過 `TatCoreUiApi` 用它做兩件事：
/// 讀 cookie、載一頁把 HTML 拿回來。
///
/// **一律用 `WKWebsiteDataStore.default()`。** 不可以改成 `.nonPersistent()`
/// 或自訂 store：登入頁寫進去的 cookie 就在這一份，換一份等於 Dart 端看不到
/// 登入結果，而症狀長得跟「憑證過期」一模一樣。
enum WebHost {
  /// 登出時把 WebView 的登入狀態（cookie、local storage…）整個清掉，下一位使用者才不會接著用前一位的 session。
  @MainActor
  static func clearWebsiteData() async {
    await WKWebsiteDataStore.default().removeData(
      ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
  }

  static func cookies(url: String, completion: @escaping ([WebCookie]) -> Void) {
    guard let target = URL(string: url), let host = target.host else {
      completion([])
      return
    }
    WKWebsiteDataStore.default().httpCookieStore.getAllCookies { all in
      let matched = all.filter { cookie in
        // domain 可能是 ".ntust.edu.tw" 或 "ssoam2.ntust.edu.tw"，兩種都要收。
        let domain = cookie.domain.hasPrefix(".")
          ? String(cookie.domain.dropFirst()) : cookie.domain
        return host == domain || host.hasSuffix("." + domain)
      }
      completion(matched.map {
        WebCookie(
          name: $0.name, value: $0.value,
          secure: $0.isSecure, httpOnly: $0.isHTTPOnly)
      })
    }
  }

  static func loadPage(
    _ request: PageLoadRequest, completion: @escaping (PageLoadResult) -> Void
  ) {
    guard let url = URL(string: request.url) else {
      completion(PageLoadResult(outcome: .error, detail: "網址無法解析：\(request.url)"))
      return
    }
    let session = PageLoadSession(request: request, url: url, completion: completion)
    session.start()
  }
}

/// 一次頁面載入。每次載入各自一個，因為三個分頁可能並行。
private final class PageLoadSession: NSObject, WKNavigationDelegate {
  private let request: PageLoadRequest
  private let url: URL
  /// 設成 nil 代表「已經收網」。等同 Dart 版每個回呼開頭的 `isCompleted` 檢查：
  /// client-side 導向會讓 didFinish 觸發第二次。
  private var completion: ((PageLoadResult) -> Void)?
  private var webView: WKWebView?
  private var timeout: DispatchWorkItem?
  /// 自己持有自己直到收網。沒有這一行，session 在 start() 回傳後就被回收，
  /// delegate 是 weak 的，於是永遠不會有人收網。
  private var retain: PageLoadSession?

  init(request: PageLoadRequest, url: URL, completion: @escaping (PageLoadResult) -> Void) {
    self.request = request
    self.url = url
    self.completion = completion
  }

  func start() {
    retain = self
    let config = WKWebViewConfiguration()
    config.websiteDataStore = WKWebsiteDataStore.default()
    // 給真實尺寸：接近零的 viewport 會讓推進轉址鏈的 document.form.submit()
    // 延後執行，整條鏈就卡住。
    let web = WKWebView(
      frame: CGRect(x: 0, y: 0, width: 412, height: 892), configuration: config)
    web.navigationDelegate = self
    webView = web

    // **要掛進 view hierarchy。** 離屏的 WKWebView 執行 JavaScript 不可靠
    // （flutter_inappwebview 的 HeadlessInAppWebView 也是為此把 view 塞進
    // key window）。alpha 設 0 且不接觸控，使用者看不到。
    if let host = Self.hostView {
      web.alpha = 0
      web.isUserInteractionEnabled = false
      host.insertSubview(web, at: 0)
    }

    let work = DispatchWorkItem { [weak self] in
      self?.finish(PageLoadResult(outcome: .timeout, detail: "逾時"))
    }
    timeout = work
    DispatchQueue.main.asyncAfter(
      deadline: .now() + .seconds(Int(request.timeoutSeconds)), execute: work)

    web.load(URLRequest(url: url))
  }

  /// 用 scene 取得視窗，不用已經棄用的 `UIApplication.shared.keyWindow`
  /// ——採用 UIScene 之後那支可能回 nil。
  private static var hostView: UIView? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard completion != nil else { return }
    let current = webView.url?.absoluteString ?? ""

    // 被踢回登入頁＝沒有有效 session，等下去不會變好。
    if request.failWhenUrlContainsAny.contains(where: { current.contains($0) }) {
      finish(PageLoadResult(outcome: .redirectedToLogin, detail: current))
      return
    }

    webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] value, _ in
      guard let self, self.completion != nil, let html = value as? String else { return }
      // **只在真的到站時才收網。** didFinish 在轉址鏈的每一站都會觸發；
      // 不符就什麼都不做，讓鏈繼續跑。判準由 Dart 傳進來。
      if self.request.completeWhenHtmlContainsAll.allSatisfy({ html.contains($0) }) {
        self.finish(PageLoadResult(outcome: .ok, html: html))
      } else {
        NSLog("[web-host] 略過中途頁 \(current)")
      }
    }
  }

  func webView(
    _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
  ) {
    finish(PageLoadResult(outcome: .error, detail: error.localizedDescription))
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    finish(PageLoadResult(outcome: .error, detail: error.localizedDescription))
  }

  private func finish(_ result: PageLoadResult) {
    guard let done = completion else { return }
    completion = nil
    timeout?.cancel()
    timeout = nil
    // 一定要拆乾淨：navigationDelegate 不解開、view 不移除的話，
    // WebView 會繼續跑轉址鏈並持有這個 session。
    webView?.navigationDelegate = nil
    webView?.stopLoading()
    webView?.removeFromSuperview()
    webView = nil
    done(result)
    retain = nil
  }
}
