import Flutter

/// Swift → Dart。Pigeon 的回呼包成 async/await，sealed 的結果轉成 `CoreResult`。
@MainActor
final class CoreClient {
  private let api: TatCoreApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatCoreApi(binaryMessenger: messenger)
  }

  /// 回答了就代表核心起來了，其他呼叫從這裡放行（`CoreGate`）。
  func launch() async throws -> AppLaunch {
    defer { CoreGate.open() }
    return try await pigeonCall(waitForCore: false) { api.launch(completion: $0) }
  }

  func needsPrivacyAgreement() async throws -> Bool {
    try await pigeonCall { api.needsPrivacyAgreement(completion: $0) }
  }

  func agreePrivacyPolicy() async throws {
    try await pigeonCall { api.agreePrivacyPolicy(completion: $0) }
  }

  func setLanguage(_ language: AppLanguage) async throws {
    try await pigeonCall { api.setLanguage(language: language, completion: $0) }
  }

  func credentials() async throws -> SavedCredentials {
    try await pigeonCall { api.credentials(completion: $0) }
  }

  func saveCredentials(account: String, password: String) async throws {
    try await pigeonCall { api.saveCredentials(account: account, password: password, completion: $0) }
  }

  func debugInteractiveSignIn(moodle: Bool) async throws -> String {
    try await pigeonCall { api.debugInteractiveSignIn(moodle: moodle, completion: $0) }
  }

  func status() async throws -> CoreStatus {
    try await pigeonCall { api.status(completion: $0) }
  }

  func courseTable(semester: String? = nil) async throws -> CoreResult<CourseTable> {
    CoreResult(try await pigeonCall { api.getCourseTable(semester: semester, completion: $0) })
  }

  func score() async throws -> CoreResult<ScoreSummary> {
    CoreResult(try await pigeonCall { api.getScore(completion: $0) })
  }
}
