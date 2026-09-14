import Foundation

/// 上一次核心的回答：登入了沒、同意過條款沒、語言與外觀。
///
/// 啟動時先照它進畫面、不等引擎，核心回答後再對一次；它只是快取，判準仍在核心。
/// key 不帶 `flutter.` 前綴，和 Flutter 外掛存在 `UserDefaults.standard` 的設定分開。
struct LaunchHint: Codable, Equatable {
  var signedIn: Bool
  var agreed: Bool
  var language: Int?
  var theme: Int?
  var brandSeed: Int64?

  private static let key = "native.launch_hint"

  static func load() -> LaunchHint? {
    UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(LaunchHint.self, from: $0) }
  }

  func save() {
    if let data = try? JSONEncoder().encode(self) {
      UserDefaults.standard.set(data, forKey: Self.key)
    }
  }
}
