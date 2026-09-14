import SwiftUI
import WebKit

/// 核心要求的可見 WebView（ssoam2 與 Moodle 的登入頁）。標題與進度提示都由核心決定。
struct WebLoginSheet: View {
  let session: WebSession
  let presenter: UiPresenter
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      WebViewContainer(session: session)
        .ignoresSafeArea(edges: .bottom)
        .overlay {
          // 自動填表時網頁不該被點到。和 Flutter 版 LoadingPage 的那一層一樣是透明的。
          if session.progressMessage != nil {
            Color.clear
              .contentShape(Rectangle())
              .onTapGesture {}
          }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { SheetCloseButton { dismiss() } }
    }
    // sheet 蓋住了 root 的 toast，這裡再掛一份，連同這一頁自己的進度提示。
    .overlay(ToastOverlay(presenter: presenter, inSheet: true, progress: session.progressMessage))
    .onDisappear { session.dismissedByUser() }
  }
}

private struct WebViewContainer: UIViewRepresentable {
  let session: WebSession

  func makeUIView(context: Context) -> WKWebView {
    session.didMoveOnScreen()
    return session.webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {}
}
