import Foundation
import UIKit

/// 挑回來的檔案先複製進 App 自己的暫存資料夾，再把路徑交給核心：挑檔器給的網址離開 callback 就讀不到。
enum PickedFiles {
  static func copy(_ urls: [URL]) -> [String] {
    guard let folder = makeFolder() else { return [] }
    return urls.compactMap { url in
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      let target = folder.appendingPathComponent(url.lastPathComponent)
      do {
        try FileManager.default.copyItem(at: url, to: target)
        return target.path
      } catch {
        return nil
      }
    }
  }

  /// 相機拍的照片存成 JPEG。刻意不縮圖：白板照片縮到長邊 1024 就讀不出字了。
  static func save(_ image: UIImage, name: String) -> String? {
    guard let folder = makeFolder(), let data = image.jpegData(compressionQuality: 0.9) else { return nil }
    let target = folder.appendingPathComponent(name)
    return (try? data.write(to: target)) == nil ? nil : target.path
  }

  static func save(_ data: Data, name: String) -> String? {
    guard let folder = makeFolder() else { return nil }
    let target = folder.appendingPathComponent(name)
    return (try? data.write(to: target)) == nil ? nil : target.path
  }

  private static func makeFolder() -> URL? {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
      "picked-\(UUID().uuidString)", isDirectory: true)
    return (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) == nil
      ? nil : folder
  }
}
