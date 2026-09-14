import Flutter
import WebKit

/// App 內瀏覽器停在學校登入頁時代填帳密。WKWebView 先掛進 `CoreWebSessions`，核心才驅動得到它。
@MainActor
final class BrowserClient {
  private let api: TatBrowserApi
  private let webSessions: CoreWebSessions

  init(messenger: FlutterBinaryMessenger, webSessions: CoreWebSessions) {
    api = TatBrowserApi(binaryMessenger: messenger)
    self.webSessions = webSessions
  }

  /// 這個 WebView 在核心那一側的編號；拿不到時回 nil，代填就不做。
  func attach(_ webView: WKWebView) async -> Int64? {
    guard let id = try? await pigeonCall({ api.reserveSession(completion: $0) }) else { return nil }
    webSessions.attach(id, webView: webView)
    return id
  }

  func detach(_ id: Int64) {
    webSessions.detach(id)
  }

  func isLoginPage(_ url: URL) async -> Bool {
    (try? await pigeonCall { api.isLoginPage(url: url.absoluteString, completion: $0) }) ?? false
  }

  func autoLogin(sessionId: Int64, url: URL) async -> BrowserLoginOutcome {
    (try? await pigeonCall {
      api.autoLogin(sessionId: sessionId, url: url.absoluteString, completion: $0)
    }) ?? .notLoginPage
  }
}
