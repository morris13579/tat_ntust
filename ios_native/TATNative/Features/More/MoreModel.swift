import Foundation
import Observation

@MainActor
@Observable
final class MoreModel {
  enum Profile {
    case loading
    case loaded(MoodleProfile)
    case failed
    case signedOut
  }

  private(set) var profile: Profile = .loading
  private(set) var signedIn = false
  private(set) var theme: ThemeChoice = .system
  private(set) var changingAvatar = false

  let client: MoreClient
  private var started = false
  private var pendingThemeColor: Task<Void, Never>?

  init(client: MoreClient) {
    self.client = client
  }

  /// 進分頁時不開登入頁：使用者只是點了一下分頁，失敗時那一列給重試。
  func start() async {
    guard !started else { return }
    started = true
    if let theme = try? await client.theme() { self.theme = theme }
    await loadProfile(interactive: false)
  }

  func loadProfile(interactive: Bool) async {
    signedIn = await client.isSignedIn()
    guard signedIn else {
      profile = .signedOut
      return
    }
    let hadProfile = if case .loaded = profile { true } else { false }
    if !hadProfile { profile = .loading }
    if let result = try? await client.profile(interactive: interactive) {
      profile = .loaded(result)
    } else if !hadProfile {
      // 抓不到就留著上一份，同 `MainController`：剛換完頭貼時 site_info 偶發失敗，不該把整列換成錯誤。
      profile = .failed
    }
  }

  func setTheme(_ theme: ThemeChoice) async {
    self.theme = theme
    try? await client.setTheme(theme)
  }

  /// 選了就先換色；設定等停下來再寫，拖顏色選擇器時不必每動一下就存一次。
  func setThemeColor(_ argb: Int64?) {
    BrandPalette.shared.apply(argb)
    pendingThemeColor?.cancel()
    pendingThemeColor = Task { [client] in
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled else { return }
      try? await client.setThemeColor(argb)
    }
  }

  /// 換頭貼，[jpeg] 是 nil 就是移除。回 nil 代表成功，否則是要顯示的訊息。
  func changeAvatar(_ jpeg: Data?) async -> String? {
    changingAvatar = true
    defer { changingAvatar = false }
    let message: String?
    do {
      message = try await client.changeAvatar(jpeg: jpeg)
    } catch {
      message = L10n.avatarUpdateError
    }
    if message == nil { await loadProfile(interactive: false) }
    return message
  }
}
