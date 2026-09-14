import SwiftUI

/// 卡片裡的一串 Moodle 檔案，點一下下載並打開，照 `MoodleFileTile`。
struct MoodleFileList: View {
  @Environment(AppEnvironment.self) private var app
  let files: [MoodleFileRow]
  /// 下載到哪個資料夾（課程名稱）。
  let folder: String

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(files.enumerated()), id: \.offset) { index, file in
        if index > 0 { Divider() }
        Button {
          Task {
            await MoodleFiles.open(
              MoodleFileLink(name: file.name, url: file.url), folder: folder, presenter: app.presenter)
          }
        } label: {
          HStack(spacing: 11) {
            LucideImage(MoodleFileIcon.of(file.fileIcon), size: 20)
              .foregroundStyle(Color.tatBrand)
            VStack(alignment: .leading, spacing: 2) {
              Text(file.name)
                .foregroundStyle(Color.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
              if let subtitle = file.subtitle {
                Text(subtitle)
                  .font(.footnote.monospacedDigit())
                  .foregroundStyle(.secondary)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            LucideImage(Lucide.download, size: 18)
              .foregroundStyle(Color.tatBrand)
          }
          .padding(.vertical, 8)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
  }
}

/// HTML 裡的連結交給核心決定怎麼開：自家檔案下載、網頁寫進 [web]，由畫面推出去。
private struct MoodleLinkHandler: ViewModifier {
  @Environment(AppEnvironment.self) private var app
  let client: CourseMoodleClient
  let folder: String
  @Binding var web: WebPage?

  func body(content: Content) -> some View {
    content.environment(
      \.openURL,
      OpenURLAction { url in
        Task { await open(url) }
        return .handled
      })
  }

  private func open(_ url: URL) async {
    guard let target = try? await client.linkTarget(url: url.absoluteString) else { return }
    switch target.kind {
    case .download:
      await MoodleFiles.open(
        MoodleFileLink(name: target.filename ?? "", url: target.url), folder: folder, presenter: app.presenter)
    case .web:
      guard let link = URL(string: target.url) else { return }
      web = WebPage(title: folder, url: link, fallbackURL: target.fallbackUrl.flatMap(URL.init(string:)))
    case .blocked:
      break
    }
  }
}

extension View {
  func moodleLinks(client: CourseMoodleClient, folder: String, web: Binding<WebPage?>) -> some View {
    modifier(MoodleLinkHandler(client: client, folder: folder, web: web))
  }
}
