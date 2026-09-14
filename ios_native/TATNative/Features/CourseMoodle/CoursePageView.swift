import SwiftUI
import WebKit

/// page 模組的 HTML 教材，照 `course_html_page.dart`。內容等同不可信：不跑 JavaScript，連結一律攔下來
/// 交給核心決定怎麼開。
struct CoursePageView: View {
  @Environment(AppEnvironment.self) private var app
  let client: CourseMoodleClient
  let course: CourseRef
  let moduleId: Int64
  let title: String
  @State private var page: CoursePage?
  @State private var web: WebPage?

  var body: some View {
    Group {
      if let page {
        if let html = page.html {
          HTMLPage(html: html, baseURL: page.baseUrl.flatMap(URL.init(string:))) { url in
            Task { await open(url) }
          }
          .ignoresSafeArea(edges: .bottom)
        } else {
          InlineErrorView(message: page.error ?? L10n.unknownError, signedIn: true, presenter: app.presenter) {
            await load()
          }
          .frame(maxHeight: .infinity, alignment: .top)
        }
      } else {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .background(Color(.systemBackground))
    .navigationTitle(title)
    .analyticsScreen("/CourseHtmlPage")
    .navigationBarTitleDisplayMode(.inline)
    .browserSheet(item: $web) { url in
      (try? await client.isAutologinScript(url: url.absoluteString)) ?? false
    }
    .task {
      if page == nil { await load() }
    }
  }

  private func load() async {
    page = (try? await client.page(courseId: course.courseId, moduleId: moduleId)) ?? CoursePage(error: L10n.unknownError)
  }

  private func open(_ url: URL) async {
    guard let target = try? await client.linkTarget(url: url.absoluteString) else { return }
    switch target.kind {
    case .download:
      await MoodleFiles.open(
        MoodleFileLink(name: target.filename ?? "", url: target.url), folder: course.name, presenter: app.presenter)
    case .web:
      guard let link = URL(string: target.url) else { return }
      web = WebPage(title: title, url: link, fallbackURL: target.fallbackUrl.flatMap(URL.init(string:)))
    case .blocked:
      break
    }
  }
}

private struct HTMLPage: UIViewRepresentable {
  let html: String
  let baseURL: URL?
  let onLink: (URL) -> Void

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.scrollView.showsVerticalScrollIndicator = false
    view.scrollView.showsHorizontalScrollIndicator = false
    view.navigationDelegate = context.coordinator
    view.loadHTMLString(html, baseURL: baseURL)
    return view
  }

  func updateUIView(_ uiView: WKWebView, context: Context) {
    context.coordinator.onLink = onLink
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onLink: onLink)
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    var onLink: (URL) -> Void

    init(onLink: @escaping (URL) -> Void) {
      self.onLink = onLink
    }

    func webView(
      _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
      // 只放行一開始載入的那一頁；使用者點的連結交給核心，iframe 也不讓它自己跳走。
      guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else {
        decisionHandler(navigationAction.navigationType == .other ? .allow : .cancel)
        return
      }
      decisionHandler(.cancel)
      onLink(url)
    }
  }
}
