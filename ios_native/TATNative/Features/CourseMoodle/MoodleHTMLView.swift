import SwiftUI

/// Moodle 原文 HTML：文字與連結照 `HTMLText` 畫，裡面的圖片排在下面。圖片網址由核心換過，
/// 自家檔案帶著憑證、其他站台只收 https。點圖片全螢幕看，照 Flutter 版的 `PhotoView`。
struct MoodleHTMLView: View {
  let html: String
  let client: CourseMoodleClient
  @State private var images: [URL] = []
  @State private var zoomed: ZoomTarget?

  private struct ZoomTarget: Identifiable {
    let url: URL
    var id: URL { url }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HTMLText(html: html)
      ForEach(images, id: \.self) { url in
        AsyncImage(url: url) { phase in
          if let image = phase.image {
            image
              .resizable()
              .scaledToFit()
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
              .onTapGesture { zoomed = ZoomTarget(url: url) }
              .accessibilityAddTraits(.isButton)
          } else if phase.error != nil {
            LucideImage(Lucide.imageOff, size: 24)
              .foregroundStyle(.tertiary)
          } else {
            ProgressView()
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .fullScreenCover(item: $zoomed) { ZoomableImageView(url: $0.url) }
    .task(id: html) {
      images = ((try? await client.htmlImages(html: html)) ?? []).compactMap(URL.init(string:))
    }
  }
}
