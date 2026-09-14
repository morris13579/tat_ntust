import Foundation
import Observation

/// Dart → Swift：`TatTransferHost` 的實作。上傳的進度照 key 放著，畫面讀自己那一趟的。
@MainActor
@Observable
final class TransferCenter: TatTransferHost {
  private(set) var progress: [String: TransferProgress] = [:]

  nonisolated func onProgress(progress: TransferProgress) throws {
    Task { @MainActor in self.progress[progress.key] = progress }
  }

  func clear(_ key: String) {
    progress[key] = nil
  }
}
