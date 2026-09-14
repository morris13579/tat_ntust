import Foundation
import QuickLook
import UIKit

/// 下載檔案存在 App 裡，用系統的預覽打開。下載過的直接開，不再抓一次，照 `FileDownload.download`。
@MainActor
enum FileDownloads {
  struct DownloadFailed: Error {}

  /// 已經下載過的那一份；沒有回 nil。[folder] 是分類用的資料夾名稱（課程名稱）。
  static func cached(name: String, folder: String) -> URL? {
    guard !name.isEmpty, let directory = try? directory(folder) else { return nil }
    let file = directory.appendingPathComponent(safeName(name))
    return FileManager.default.fileExists(atPath: file.path) ? file : nil
  }

  /// [name] 是空的時候照伺服器的 Content-Disposition 取名。[progress] 收 0...1，在背景執行緒上呼叫。
  static func download(
    _ url: URL, name: String, folder: String, progress: @escaping @Sendable (Double) -> Void = { _ in }
  ) async throws -> URL {
    let (temporary, response) = try await URLSession.shared.download(
      from: url, delegate: DownloadProgress(onChange: progress))
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw DownloadFailed()
    }
    AppAnalytics.fileDownload()
    let fileName = safeName(name.isEmpty ? (response.suggestedFilename ?? url.lastPathComponent) : name)
    let target = try directory(folder).appendingPathComponent(fileName)
    try? FileManager.default.removeItem(at: target)
    try FileManager.default.moveItem(at: temporary, to: target)
    return target
  }

  /// WKDownload 要先給目的地。同名的舊檔先刪掉，否則下載會直接失敗。
  static func destination(name: String, folder: String) throws -> URL {
    let target = try directory(folder).appendingPathComponent(safeName(name))
    try? FileManager.default.removeItem(at: target)
    return target
  }

  static func preview(_ file: URL) {
    FilePreview.present(file)
  }

  private static func directory(_ folder: String) throws -> URL {
    let base = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let directory = base.appendingPathComponent("downloads", isDirectory: true)
      .appendingPathComponent(safeName(folder), isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// 檔名接進路徑之前先拿掉分隔符：`..` 或帶斜線的名字會寫到資料夾外面。
  private static func safeName(_ name: String) -> String {
    let cleaned = name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
    return cleaned.isEmpty || cleaned == "." || cleaned == ".." ? "file" : cleaned
  }
}

/// QLPreviewController 的資料來源要活到預覽關掉，所以自己留一份。
private final class FilePreview: NSObject, QLPreviewControllerDataSource {
  @MainActor private static var current: FilePreview?
  private let file: URL

  private init(file: URL) {
    self.file = file
  }

  @MainActor static func present(_ file: URL) {
    let preview = FilePreview(file: file)
    current = preview
    let controller = QLPreviewController()
    controller.dataSource = preview
    TopViewController.find()?.present(controller, animated: true)
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
    file as NSURL
  }
}

/// `URLSession.download(from:delegate:)` 不會把寫入進度交給 delegate，改盯任務自己的 `Progress`。
private final class DownloadProgress: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let onChange: @Sendable (Double) -> Void
  private var observation: NSKeyValueObservation?

  init(onChange: @escaping @Sendable (Double) -> Void) {
    self.onChange = onChange
  }

  func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
    observation = task.progress.observe(\.fractionCompleted) { [onChange] progress, _ in
      onChange(progress.fractionCompleted)
    }
  }
}
