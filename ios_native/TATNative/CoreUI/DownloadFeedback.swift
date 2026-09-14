import SwiftUI
import UserNotifications

/// 下載的回饋，照 Flutter 版 `FileDownload`：下載中看得到進度，完成或失敗各發一則通知，點「下載完成」打開檔案。
/// iOS 的通知放不了進度條，進度改用畫面上的膠囊，下載時照樣能操作別的東西。
@MainActor
enum DownloadFeedback {
  /// 通知帶著檔案路徑，`PushNotifications` 點下去時用它打開。
  nonisolated static let fileKey = "downloadFile"

  /// [work] 拿到一個回報進度（0...1）的 closure；拿不到進度的就不必呼叫，膠囊會一直轉。
  static func run(
    name: String, presenter: UiPresenter,
    _ work: (@escaping @Sendable (Double) -> Void) async throws -> URL
  ) async -> URL? {
    let id = presenter.beginDownload(L10n.downloading)
    defer { presenter.endDownload(id) }
    do {
      let file = try await work { value in
        Task { @MainActor in presenter.updateDownload(id, progress: value) }
      }
      notify(title: name, body: L10n.downloadComplete, file: file)
      return file
    } catch {
      presenter.toast(L10n.downloadError, kind: .error)
      notify(title: name, body: L10n.downloadError, file: nil)
      return nil
    }
  }

  static func notify(title: String, body: String, file: URL?) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    if let file { content.userInfo = [fileKey: file.path] }
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
  }
}
