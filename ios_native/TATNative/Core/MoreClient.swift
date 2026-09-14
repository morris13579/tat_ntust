import Flutter

/// 「更多」分頁的核心呼叫。
@MainActor
final class MoreClient {
  private let api: TatMoreApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatMoreApi(binaryMessenger: messenger)
  }

  func isSignedIn() async -> Bool {
    (try? await pigeonCall { api.isSignedIn(completion: $0) }) ?? false
  }

  func profile(interactive: Bool) async throws -> MoodleProfile? {
    try await pigeonCall { api.profile(interactive: interactive, completion: $0) }
  }

  func changeAvatar(jpeg: Data?) async throws -> String? {
    try await pigeonCall {
      api.changeAvatar(jpeg: jpeg.map { FlutterStandardTypedData(bytes: $0) }, completion: $0)
    }
  }

  func theme() async throws -> ThemeChoice {
    try await pigeonCall { api.theme(completion: $0) }
  }

  func setTheme(_ theme: ThemeChoice) async throws {
    try await pigeonCall { api.setTheme(theme: theme, completion: $0) }
  }

  func themeColor() async throws -> Int64? {
    try await pigeonCall { api.themeColor(completion: $0) }
  }

  func setThemeColor(_ argb: Int64?) async throws {
    try await pigeonCall { api.setThemeColor(argb: argb, completion: $0) }
  }

  func feedbackUrl() async throws -> String {
    try await pigeonCall { api.feedbackUrl(completion: $0) }
  }

  func contributors() async throws -> [ProjectContributor]? {
    try await pigeonCall { api.contributors(completion: $0) }
  }

  func logout() async throws {
    try await pigeonCall { api.logout(completion: $0) }
  }
}
