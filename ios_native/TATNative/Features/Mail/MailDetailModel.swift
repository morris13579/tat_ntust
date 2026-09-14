import Foundation
import Observation

@MainActor
@Observable
final class MailDetailModel {
  let client: MailClient
  let ref: String
  private(set) var header: MailHeader?
  /// nil 代表還在載入。
  private(set) var content: MailBody?
  /// 正在下載的附件：同一個附件不要讓人連按兩次各抓一份。
  private(set) var downloading: Set<String> = []
  private(set) var moving = false
  /// 只放行這一次瀏覽，不落盤：那等於把預設值悄悄改掉。
  var showRemoteImages = false
  /// 大宗郵件的收件者是投遞群組位址，對讀信的人沒有用，預設收起來。
  var showRecipients = false
  var bodyHeight: CGFloat = 1

  init(client: MailClient, ref: String) {
    self.client = client
    self.ref = ref
  }

  func load() async {
    if header == nil { header = try? await client.header(ref: ref) }
    content = nil
    content =
      (try? await client.body(ref: ref))
      ?? MailBody(attachments: [], remoteImages: false, error: L10n.mailBodyLoadFailed)
  }

  /// 走跟課程檔案同一個下載資料夾，使用者只要記得一個地方。
  func download(_ attachment: MailAttachmentRow, presenter: UiPresenter) async {
    guard !downloading.contains(attachment.fetchId) else { return }
    downloading.insert(attachment.fetchId)
    defer { downloading.remove(attachment.fetchId) }
    // 附件是核心那一側存的，拿不到進度，膠囊一直轉到存完。
    let file = await DownloadFeedback.run(name: attachment.name, presenter: presenter) { _ in
      let destination = try FileDownloads.destination(name: attachment.name, folder: L10n.mailTitle)
      guard try await client.saveAttachment(ref: ref, fetchId: attachment.fetchId, destination: destination.path)
      else { throw FileDownloads.DownloadFailed() }
      return destination
    }
    if let file { FileDownloads.preview(file) }
  }

  /// 成功回 true，由頁面自己離開。
  func move(archive: Bool, presenter: UiPresenter) async -> Bool {
    guard !moving else { return false }
    moving = true
    defer { moving = false }
    guard (try? await client.move(ref: ref, archive: archive)) == true else {
      presenter.toast(L10n.mailActionFailed, kind: .error)
      return false
    }
    return true
  }
}
