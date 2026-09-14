import SwiftUI
import UIKit

/// 分享課表，照 `share_table_sheet.dart`：一張 QR，加上「這是誰的、哪一學期」的落款。
struct ShareTableSheet: View {
  let share: TableShare
  let presenter: UiPresenter

  var body: some View {
    SheetStack(title: L10n.shareTableTitle) {
      ScrollView {
        VStack(spacing: 0) {
          QRCard(text: share.qr)
          Text(L10n.shareTableHint)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 14)
          Text(share.studentId)
            .font(.title3.weight(.semibold).monospacedDigit())
            .padding(.top, 16)
          Text(summary)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.top, 2)

          Button(action: saveImage) {
            Label {
              Text(L10n.shareTableSaveImage)
            } icon: {
              LucideImage(Lucide.download, size: 18)
            }
            .frame(maxWidth: .infinity)
          }
          .prominentButtonStyle()
          .controlSize(.large)
          .padding(.top, 20)

          Button {
            UIPasteboard.general.string = share.code
            presenter.toast(L10n.shareTableCodeCopied, kind: .success)
          } label: {
            // 跟上面的大按鈕一樣高：只有一行字高的話，兩顆鈕看起來黏在一起。
            Text(L10n.shareTableCopyCode)
              .frame(maxWidth: .infinity, minHeight: 50)
              .contentShape(Rectangle())
          }
          .controlSize(.large)
          .padding(.top, 8)

          HStack(alignment: .firstTextBaseline, spacing: 8) {
            LucideImage(Lucide.info, size: 14)
              .alignedToFirstTextLine(.footnote)
            Text(L10n.shareTableNote)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .font(.footnote)
          .foregroundStyle(.secondary)
          .padding(.top, 12)
        }
        .padding(.horizontal, 20)
      }
    }
    .overlay(ToastOverlay(presenter: presenter, inSheet: true))
  }

  private var summary: String {
    [share.semester, TableText.summary(courses: share.courseCount, credits: share.credits)]
      .joined(separator: " · ")
  }

  private func saveImage() {
    let renderer = ImageRenderer(content: QRCard(text: share.qr))
    renderer.scale = 3
    guard let png = renderer.uiImage?.pngData() else { return }
    ShareSheet.present(pngData: png, fileName: "tat-course-table-qr.png")
  }
}

/// QR 那一塊。刻意不跟著深色模式反白：黑白對比是掃描器的判讀條件，存成圖片傳出去之後也沒得補救。
struct QRCard: View {
  let text: String

  var body: some View {
    Group {
      if let image = QRCode.image(for: text) {
        Image(uiImage: image)
          .interpolation(.none)
          .resizable()
          .frame(width: 200, height: 200)
      }
    }
    .padding(16)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}
