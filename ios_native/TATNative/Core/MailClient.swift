import Flutter

/// 信箱分頁、信件內頁與寫信頁的核心呼叫。清單狀態不從這裡回來，由 `MailCenter` 收推送。
@MainActor
final class MailClient {
  private let api: TatMailApi
  private let message: TatMailMessageApi
  private let composer: TatMailComposeApi

  init(messenger: FlutterBinaryMessenger) {
    api = TatMailApi(binaryMessenger: messenger)
    message = TatMailMessageApi(binaryMessenger: messenger)
    composer = TatMailComposeApi(binaryMessenger: messenger)
  }

  // MARK: - 分頁

  func status() async throws -> MailStatus {
    try await pigeonCall { api.status(completion: $0) }
  }

  func setup(password: String) async throws -> MailSetupResult {
    try await pigeonCall { api.setup(password: password, completion: $0) }
  }

  func open() async throws {
    try await pigeonCall { api.open(completion: $0) }
  }

  func reload() async throws {
    try await pigeonCall { api.reload(completion: $0) }
  }

  func openFolder(_ path: String) async throws {
    try await pigeonCall { api.openFolder(path: path, completion: $0) }
  }

  func search(_ keyword: String, allFolders: Bool) async throws {
    try await pigeonCall { api.search(keyword: keyword, allFolders: allFolders, completion: $0) }
  }

  func endSearch() async throws {
    try await pigeonCall { api.endSearch(completion: $0) }
  }

  func loadMore() async throws {
    try await pigeonCall { api.loadMore(completion: $0) }
  }

  func markSeen(ref: String) async throws {
    try await pigeonCall { api.markSeen(ref: ref, completion: $0) }
  }

  func setSeen(ref: String, seen: Bool) async throws -> Bool {
    try await pigeonCall { api.setSeen(ref: ref, seen: seen, completion: $0) }
  }

  func moveToTrash(ref: String) async throws -> Bool {
    try await pigeonCall { api.moveToTrash(ref: ref, completion: $0) }
  }

  func archive(ref: String) async throws -> Bool {
    try await pigeonCall { api.archive(ref: ref, completion: $0) }
  }

  func moveToFolder(ref: String, target: String) async throws -> Bool {
    try await pigeonCall { api.moveToFolder(ref: ref, target: target, completion: $0) }
  }

  func startWatch() async throws {
    try await pigeonCall { api.startWatch(completion: $0) }
  }

  func stopWatch() async throws {
    try await pigeonCall { api.stopWatch(completion: $0) }
  }

  func restoreOutbox() async throws {
    try await pigeonCall { api.restoreOutbox(completion: $0) }
  }

  func recall(id: Int64) async throws -> Bool {
    try await pigeonCall { api.recall(id: id, completion: $0) }
  }

  func retry(id: Int64) async throws {
    try await pigeonCall { api.retry(id: id, completion: $0) }
  }

  // MARK: - 內頁

  func header(ref: String) async throws -> MailHeader? {
    try await pigeonCall { message.header(ref: ref, completion: $0) }
  }

  func body(ref: String) async throws -> MailBody {
    try await pigeonCall { message.body(ref: ref, completion: $0) }
  }

  func saveAttachment(ref: String, fetchId: String, destination: String) async throws -> Bool {
    try await pigeonCall {
      message.saveAttachment(ref: ref, fetchId: fetchId, destination: destination, completion: $0)
    }
  }

  func markMessageSeen(ref: String) async throws {
    try await pigeonCall { message.markSeen(ref: ref, completion: $0) }
  }

  func move(ref: String, archive: Bool) async throws -> Bool {
    try await pigeonCall { message.move(ref: ref, archive: archive, completion: $0) }
  }

  // MARK: - 寫信

  func startCompose(kind: MailComposeKind, ref: String) async throws -> MailComposeStart {
    try await pigeonCall { composer.start(kind: kind, ref: ref, completion: $0) }
  }

  func addRecipients(existing: [String], raw: String) async throws -> [MailRecipient] {
    try await pigeonCall { composer.addRecipients(existing: existing, raw: raw, completion: $0) }
  }

  func suggest(query: String, taken: [String]) async throws -> [MailContactRow] {
    try await pigeonCall { composer.suggest(query: query, taken: taken, completion: $0) }
  }

  func checkAttachments(existing: [String], picked: [String]) async throws -> MailAttachCheck {
    try await pigeonCall { composer.checkAttachments(existing: existing, picked: picked, completion: $0) }
  }

  func send(_ request: MailSendRequest) async throws -> MailSendResult {
    try await pigeonCall { composer.send(request: request, completion: $0) }
  }
}
