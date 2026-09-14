/// Pigeon 的回呼包成 async/await。
///
/// 預設等核心起來才送：`coreMain` 裝好橋接之前，每個 channel 只排得下一則訊息，同一支方法多送的會被丟掉、回 channel-error。
@MainActor
func pigeonCall<T>(
  waitForCore: Bool = true,
  _ body: (@escaping (Result<T, PigeonError>) -> Void) -> Void
) async throws -> T {
  if waitForCore { await CoreGate.wait() }
  return try await withCheckedThrowingContinuation { continuation in
    body { continuation.resume(with: $0) }
  }
}

/// `TatCoreApi.launch` 回答（或失敗）時打開，在那之前的呼叫在這裡排隊。
@MainActor
enum CoreGate {
  private static var isOpen = false
  private static var waiting: [CheckedContinuation<Void, Never>] = []

  static func wait() async {
    guard !isOpen else { return }
    await withCheckedContinuation { waiting.append($0) }
  }

  static func open() {
    guard !isOpen else { return }
    isOpen = true
    waiting.forEach { $0.resume() }
    waiting.removeAll()
  }
}
