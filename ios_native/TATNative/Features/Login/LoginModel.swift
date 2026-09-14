import Observation

@MainActor
@Observable
final class LoginModel {
  var account = ""
  var password = ""
  var passwordHidden = true
  private(set) var accountMissing = false
  private(set) var passwordMissing = false
  private(set) var isLoading = true
  private(set) var isSaving = false

  private let core: CoreClient
  private let presenter: UiPresenter

  init(core: CoreClient, presenter: UiPresenter) {
    self.core = core
    self.presenter = presenter
  }

  func load() async {
    defer { isLoading = false }
    guard let saved = try? await core.credentials() else { return }
    // 使用者可能在核心回答前就開始打字，不要蓋掉。
    if account.isEmpty { account = saved.account }
    if password.isEmpty { password = saved.password }
  }

  /// 只存、不登入，與 `LoginController.onLoginEvent` 一致。存好回 true。
  func save() async -> Bool {
    accountMissing = account.trimmingCharacters(in: .whitespaces).isEmpty
    passwordMissing = password.trimmingCharacters(in: .whitespaces).isEmpty
    guard !accountMissing, !passwordMissing else { return false }

    isSaving = true
    defer { isSaving = false }
    do {
      try await core.saveCredentials(account: account, password: password)
      presenter.toast(L10n.loginSave, kind: .success)
      return true
    } catch {
      presenter.toast(L10n.unknownError, kind: .error)
      return false
    }
  }
}
