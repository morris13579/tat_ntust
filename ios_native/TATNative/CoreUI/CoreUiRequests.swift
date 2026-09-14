import Foundation

/// 畫面底部的提示。規格照 Flutter 版的 `TatBottomPill` / `TatToast`。
struct ToastItem: Identifiable, Equatable {
  enum Kind { case success, info, error }

  let id = UUID()
  let message: String
  let kind: Kind
  /// nil 代表不自動收——那是進度提示。
  let autoClose: Duration?
  /// 膠囊右邊那顆鈕，照 `TatToast.action`。有鈕的才吃點擊。
  var action: ToastAction?
  /// 蓋掉依 [kind] 決定的圖示。
  var icon: LucideIcon?
  /// 下載中的進度（0...1）；nil 是轉圈圈。
  var progress: Double?

  /// 進度提示不佔「同時只留一則」的名額。
  var sticky: Bool { autoClose == nil }

  static func == (lhs: ToastItem, rhs: ToastItem) -> Bool { lhs.id == rhs.id }
}

struct ToastAction {
  let label: String
  let run: () -> Void
}

/// 從畫面上緣落下來、點得下去的提示，照 Flutter 版的 `InAppBanner`。
struct BannerItem: Identifiable, Equatable {
  let id = UUID()
  let icon: LucideIcon
  let title: String
  let message: String
  let onTap: () -> Void

  static func == (lhs: BannerItem, rhs: BannerItem) -> Bool { lhs.id == rhs.id }
}

/// 一次錯誤對話框。completion 停在這裡直到使用者回答。
struct DialogRequest: Identifiable {
  let id = UUID()
  let request: ErrorDialogRequest
  let completion: (RetryChoice) -> Void
}

struct ChooserRequest: Identifiable {
  let id = UUID()
  let title: String
  let options: [ChooseOption]
  /// 取消時帶 nil。**呼叫端不可以自己挑一個頂替。**
  let completion: (String?) -> Void
}

/// class：點選項會關掉 sheet、關掉又會走到 onDisappear，回答只能給一次。
final class SemesterRequest: Identifiable {
  let id = UUID()
  let allowNull: Bool
  private var completion: ((String?) -> Void)?

  init(allowNull: Bool, completion: @escaping (String?) -> Void) {
    self.allowNull = allowNull
    self.completion = completion
  }

  func finish(_ value: String?) {
    guard let completion else { return }
    self.completion = nil
    completion(value)
  }
}
