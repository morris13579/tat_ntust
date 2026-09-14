import SwiftUI

/// 核心要求畫的東西全部收在這裡：toast、進度框、對話框、登入頁。
@Observable
final class UiPresenter {
  /// 由下往上堆。進度提示與一般提示同時在時不會疊在一起。
  private(set) var toasts: [ToastItem] = []

  /// >0 時蓋一層擋點擊的透明蓋板。刻意透明：擋住點擊就夠了，不必把畫面壓暗。
  private(set) var blockingCount = 0

  /// 主畫面分頁列的高度：提示要浮在分頁列上面，不是蓋在上面。由 `MainTabView` 量好寫進來。
  var bottomBarInset: CGFloat = 0

  /// 計數器而不是 bool：同一次啟動可能被要求第二次，bool 沒變就不會觸發 `onChange`。
  private(set) var loginRequests = 0
  private var loginClosedHandlers: [() -> Void] = []

  var dialog: DialogRequest?
  var chooser: ChooserRequest?
  var semesterRequest: SemesterRequest?
  /// 核心開的可見 WebView（登入頁）。
  var webSession: WebSession?

  private var progress: [Int64: UUID] = [:]
  private var nextHandle: Int64 = 1

  // MARK: - Toast

  /// 新的一句直接蓋掉上一句。帶 [action] 時 [duration] 通常就是那顆鈕真的有效的時間。
  func toast(
    _ message: String, kind: ToastItem.Kind = .info, icon: LucideIcon? = nil, action: ToastAction? = nil,
    duration: Duration? = nil
  ) {
    // 錯誤停久一點：那句話通常比較長。
    let duration = duration ?? (kind == .error ? .seconds(4) : .seconds(2))
    let item = ToastItem(message: message, kind: kind, autoClose: duration, action: action, icon: icon)
    // 舊的那一則立刻拿掉、不跑退場動畫：兩則形狀位置相同，淡出會和新的交疊，看起來像閃了一下。
    toasts.removeAll { !$0.sticky }
    withAnimation(.easeOut(duration: 0.16)) { toasts.append(item) }

    Task { [weak self] in
      try? await Task.sleep(for: duration)
      self?.remove(item.id)
    }
  }

  func remove(_ id: UUID) {
    guard toasts.contains(where: { $0.id == id }) else { return }
    withAnimation(.easeIn(duration: 0.12)) { toasts.removeAll { $0.id == id } }
  }

  // MARK: - 下載

  /// 下載中的膠囊：不擋點擊，下載時照樣能滑別的東西。回傳的 id 用來更新進度、收掉。
  func beginDownload(_ message: String) -> UUID {
    let item = ToastItem(message: message, kind: .info, autoClose: nil)
    withAnimation(.easeOut(duration: 0.16)) { toasts.append(item) }
    return item.id
  }

  func updateDownload(_ id: UUID, progress: Double) {
    guard let index = toasts.firstIndex(where: { $0.id == id }) else { return }
    toasts[index].progress = min(max(progress, 0), 1)
  }

  func endDownload(_ id: UUID) {
    remove(id)
  }

  // MARK: - 橫幅

  /// 同一時間只留一個：新信一次來三封時換掉前一個，不疊成一疊。
  private(set) var banner: BannerItem?

  func showBanner(icon: LucideIcon, title: String, message: String, onTap: @escaping () -> Void) {
    let item = BannerItem(icon: icon, title: title, message: message, onTap: onTap)
    withAnimation(.easeOut(duration: 0.32)) { banner = item }
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(5))
      if self?.banner?.id == item.id { self?.dismissBanner() }
    }
  }

  func dismissBanner() {
    guard banner != nil else { return }
    withAnimation(.easeIn(duration: 0.2)) { banner = nil }
  }

  // MARK: - 進度框

  func beginProgress(_ message: String) -> Int64 {
    let handle = nextHandle
    nextHandle += 1
    let item = ToastItem(message: message, kind: .info, autoClose: nil)
    progress[handle] = item.id
    blockingCount += 1
    withAnimation(.easeOut(duration: 0.16)) { toasts.append(item) }
    return handle
  }

  /// 只關掉這一個，重複呼叫是 no-op。
  func dismissProgress(_ handle: Int64) {
    guard let id = progress.removeValue(forKey: handle) else { return }
    blockingCount = max(0, blockingCount - 1)
    remove(id)
  }

  // MARK: - 對話框

  func ask(_ request: ErrorDialogRequest, completion: @escaping (RetryChoice) -> Void) {
    dialog = DialogRequest(request: request, completion: completion)
  }

  func choose(title: String, options: [ChooseOption], completion: @escaping (String?) -> Void) {
    chooser = ChooserRequest(title: title, options: options, completion: completion)
  }

  func chooseSemester(allowNull: Bool, completion: @escaping (String?) -> Void) {
    semesterRequest = SemesterRequest(allowNull: allowNull, completion: completion)
  }

  // MARK: - 登入頁

  /// `onClosed` 在登入頁關掉時呼叫，存了或取消都算。
  func requestLogin(onClosed: (() -> Void)? = nil) {
    if let onClosed { loginClosedHandlers.append(onClosed) }
    loginRequests += 1
  }

  func loginClosed() {
    let handlers = loginClosedHandlers
    loginClosedHandlers.removeAll()
    handlers.forEach { $0() }
  }
}

extension UiPresenter {
  /// 權限被拒的提示，照 Flutter 版那幾句「請到系統設定開啟後再試」；右邊直接給一顆去設定的鈕。
  func toastPermissionDenied(_ message: String) {
    toast(message, kind: .error, action: ToastAction(label: L10n.setting) {
      guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
      UIApplication.shared.open(url)
    })
  }
}
