import SwiftUI
import UIKit
import WebKit

struct WebPage: Hashable, Identifiable {
  let title: String
  let url: URL
  /// [url] 是免登入網址時原本要開的那一個。
  var fallbackURL: URL?
  var id: URL { url }
}

@MainActor
@Observable
final class WebPageModel {
  let page: WebPage
  private(set) var progress = 0.0
  private(set) var isLoading = true
  private(set) var currentURL: URL
  private(set) var fellBack = false
  private(set) var canGoForward = false
  /// 正在代填帳密。認出登入頁時打開，離開登入頁就關掉。
  private(set) var autoLogin = false
  /// 代填被驗證碼擋下來了。這是整個瀏覽器唯一需要使用者動手的時刻。
  private(set) var captcha = false
  /// 剛下載完的檔名。
  private(set) var downloaded: String?
  private(set) var downloadFailed = false

  /// 一律用 `WKWebsiteDataStore.default()`：登入寫進去的 cookie 就在這一份。
  @ObservationIgnored let webView: WKWebView
  @ObservationIgnored private let navigator = Navigator()
  @ObservationIgnored private let isKeyRejected: (URL) async -> Bool
  @ObservationIgnored private var progressObservation: NSKeyValueObservation?
  @ObservationIgnored private var started = false
  @ObservationIgnored private var browser: BrowserClient?
  /// 這個 WebView 在核心那一側的編號，代填帳密時核心用它跑 JavaScript。
  @ObservationIgnored private var sessionId: Int64?
  @ObservationIgnored private var downloads: [ObjectIdentifier: URL] = [:]

  init(page: WebPage, isKeyRejected: @escaping (URL) async -> Bool) {
    self.page = page
    self.isKeyRejected = isKeyRejected
    currentURL = page.url
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    webView = WKWebView(frame: .zero, configuration: configuration)
    webView.allowsBackForwardNavigationGestures = true
    webView.navigationDelegate = navigator
    navigator.model = self
  }

  /// 等畫面真的出現才載入：SwiftUI 可能先建好幾個沒用上的 model。先掛進核心再載入，第一頁就是登入頁時才代填得到。
  func start(browser: BrowserClient) {
    guard !started else { return }
    started = true
    self.browser = browser
    progressObservation = webView.observe(\.estimatedProgress) { [weak self] view, _ in
      Task { @MainActor in self?.progress = view.estimatedProgress }
    }
    Task {
      sessionId = await browser.attach(webView)
      webView.load(URLRequest(url: page.url))
    }
  }

  func goForward() {
    webView.goForward()
  }

  func reload() {
    webView.reload()
  }

  /// 帶著登入狀態的 WebView 可以被課程裡的連結帶去任何地方，離開學校網站時要看得出來。
  var isExternal: Bool {
    guard let host = currentURL.host(), !host.isEmpty else { return false }
    return !host.hasSuffix("ntust.edu.tw")
  }

  fileprivate func didStart(_ url: URL?) {
    isLoading = true
    downloaded = nil
    downloadFailed = false
    guard let url else { return }
    currentURL = url
    guard autoLogin || captcha, let browser else { return }
    Task {
      if !(await browser.isLoginPage(url)) {
        autoLogin = false
        captcha = false
      }
    }
  }

  fileprivate func didFinish(_ url: URL?) async {
    isLoading = false
    canGoForward = webView.canGoForward
    guard let url else { return }
    currentURL = url
    // 免登入連結成功時會轉走，停在 autologin.php 本身就是鑰匙被拒（過期、IP 不符、用過了）。
    if let fallback = page.fallbackURL, !fellBack, await isKeyRejected(url) {
      fellBack = true
      webView.load(URLRequest(url: fallback))
      return
    }
    guard let browser, let sessionId, await browser.isLoginPage(url) else { return }
    autoLogin = true
    // 代填失敗最常見的原因就是驗證碼。提示留在畫面上而不是跳 toast：人還在那一頁，toast 幾秒就沒了。
    if await browser.autoLogin(sessionId: sessionId, url: url) == .needsHuman {
      autoLogin = false
      captcha = true
    }
  }

  fileprivate func destination(for download: WKDownload, suggestedFilename: String) -> URL? {
    guard let file = try? FileDownloads.destination(name: suggestedFilename, folder: "WebView") else { return nil }
    AppAnalytics.fileDownload()
    downloads[ObjectIdentifier(download)] = file
    return file
  }

  fileprivate func didDownload(_ download: WKDownload) {
    guard let file = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
    downloaded = file.lastPathComponent
    DownloadFeedback.notify(title: file.lastPathComponent, body: L10n.downloadComplete, file: file)
    FileDownloads.preview(file)
  }

  fileprivate func downloadDidFail(_ download: WKDownload) {
    let file = downloads.removeValue(forKey: ObjectIdentifier(download))
    downloadFailed = true
    DownloadFeedback.notify(title: file?.lastPathComponent ?? page.title, body: L10n.downloadError, file: nil)
  }

  fileprivate func didFail() {
    isLoading = false
  }
}

@MainActor
private final class Navigator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
  weak var model: WebPageModel?

  func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction
  ) async -> WKNavigationActionPolicy {
    navigationAction.shouldPerformDownload ? .download : .allow
  }

  /// 顯示不了的檔案（壓縮檔、Office 文件）改成下載，照 `InAppWebViewPage` 的 `onDownloadStartRequest`。
  func webView(
    _ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse
  ) async -> WKNavigationResponsePolicy {
    navigationResponse.canShowMIMEType ? .allow : .download
  }

  func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
    download.delegate = self
  }

  func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
    download.delegate = self
  }

  func download(
    _ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String
  ) async -> URL? {
    model?.destination(for: download, suggestedFilename: suggestedFilename)
  }

  func downloadDidFinish(_ download: WKDownload) {
    model?.didDownload(download)
  }

  func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
    model?.downloadDidFail(download)
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    model?.didStart(webView.url)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    Task { await model?.didFinish(webView.url) }
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    model?.didFail()
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
  ) {
    model?.didFail()
  }
}

/// App 內開網頁，照 `inapp_web_view_page.dart`：用登入時的 cookie、免登入連結被拒時退回原網址、
/// 停在學校登入頁時代填帳密、顯示不了的檔案改成下載、離開學校網站時在上面提醒；右上角可以重新整理、
/// 下一頁、複製網址、分享、改用瀏覽器開。
struct WebPageView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: WebPageModel

  init(page: WebPage, isKeyRejected: @escaping (URL) async -> Bool) {
    _model = State(initialValue: WebPageModel(page: page, isKeyRejected: isKeyRejected))
  }

  var body: some View {
    VStack(spacing: 0) {
      notice
      WebViewHost(webView: model.webView)
        // WKWebView 自己會替工具列與分頁列留內距，讓網頁捲到它們後面。
        .ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .top) {
          if model.isLoading {
            ProgressView(value: model.progress)
              .progressViewStyle(.linear)
              .tint(Color.tatBrand)
          }
        }
    }
    .navigationTitle(model.page.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button {
          model.reload()
        } label: {
          LucideImage(Lucide.refreshCw, size: 20)
        }
        .accessibilityLabel(L10n.refresh)
        .toolbarButtonTint()

        Menu {
          if model.canGoForward {
            Button {
              model.goForward()
            } label: {
              Label { Text(L10n.browserForward) } icon: { Image(uiImage: Lucide.chevronRight.uiImage()) }
            }
          }
          Button {
            UIPasteboard.general.url = model.currentURL
            app.presenter.toast(L10n.browserUrlCopied, kind: .success)
          } label: {
            Label { Text(L10n.browserCopyUrl) } icon: { Image(uiImage: Lucide.copy.uiImage()) }
          }
          ShareLink(item: model.currentURL) {
            Label { Text(L10n.browserShare) } icon: { Image(uiImage: Lucide.share2.uiImage()) }
          }
          Button {
            UIApplication.shared.open(model.currentURL)
          } label: {
            Label { Text(L10n.openInBrowser) } icon: { Image(uiImage: Lucide.externalLink.uiImage()) }
            Text(L10n.browserOpenExternalNote)
          }
        } label: {
          LucideImage(Lucide.ellipsis, size: 20)
        }
        .accessibilityLabel(L10n.titleMore)
        .toolbarButtonTint()
      }
    }
    .onAppear { model.start(browser: app.browser) }
    .analyticsScreen("/InAppWebViewPage")
  }

  /// 同一時間只出現一條，優先序由上而下。
  @ViewBuilder private var notice: some View {
    if model.autoLogin {
      NoticeBar(message: L10n.browserAutoLoginNotice, kind: .info, icon: Lucide.info)
    } else if model.captcha {
      NoticeBar(message: L10n.browserCaptchaNotice, kind: .warning, icon: Lucide.triangleAlert)
    } else if model.fellBack {
      NoticeBar(
        message: L10n.browserAutologinExpired, kind: .warning, icon: Lucide.circleAlert,
        actionLabel: L10n.browserRelogin
      ) {
        model.reload()
      }
    } else if model.isExternal {
      NoticeBar(message: L10n.browserExternalSite, kind: .warning, icon: Lucide.externalLink)
    } else if let name = model.downloaded {
      NoticeBar(message: L10n.browserDownloadSaved(name), kind: .info, icon: Lucide.download)
    } else if model.downloadFailed {
      NoticeBar(message: L10n.downloadError, kind: .error)
    }
  }
}

private struct WebViewHost: UIViewRepresentable {
  let webView: WKWebView

  func makeUIView(context: Context) -> WKWebView { webView }

  func updateUIView(_ uiView: WKWebView, context: Context) {}
}

extension View {
  /// 瀏覽器一律開成 sheet：看完往下滑就回到原本那一頁。
  func browserSheet(item: Binding<WebPage?>, isKeyRejected: @escaping (URL) async -> Bool) -> some View {
    sheet(item: item) { page in
      BrowserSheet(page: page, isKeyRejected: isKeyRejected) { item.wrappedValue = nil }
    }
  }
}

private struct BrowserSheet: View {
  @Environment(AppEnvironment.self) private var app
  let page: WebPage
  let isKeyRejected: (URL) async -> Bool
  let onClose: () -> Void

  var body: some View {
    NavigationStack {
      WebPageView(page: page, isKeyRejected: isKeyRejected)
        .toolbar { SheetCloseButton(label: L10n.close, action: onClose) }
    }
    .overlay(ToastOverlay(presenter: app.presenter, inSheet: true))
  }
}
