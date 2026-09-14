import Foundation
import Observation

/// Dart → Swift：`TatMailHost` 的實作。清單與寄件匣照最新的快照放著；新信與寄送結果帶一個遞增的序號，
/// 畫面靠它接住每一次——同樣的內容可能連來兩次。
@MainActor
@Observable
final class MailCenter: TatMailHost {
  private(set) var list: MailListState?
  private(set) var outbox: [MailOutboxRow] = []
  private(set) var arrival: MailArrival?
  private(set) var arrivals = 0
  private(set) var lastSent = false
  private(set) var sentCount = 0

  nonisolated func onList(state: MailListState) throws {
    MainActor.assumeIsolated { list = state }
  }

  nonisolated func onOutbox(rows: [MailOutboxRow]) throws {
    MainActor.assumeIsolated { outbox = rows }
  }

  nonisolated func onArrival(arrival: MailArrival) throws {
    MainActor.assumeIsolated {
      self.arrival = arrival
      arrivals += 1
    }
  }

  nonisolated func onSent(sent: Bool) throws {
    MainActor.assumeIsolated {
      lastSent = sent
      sentCount += 1
    }
  }

  /// 登出：下一位使用者不該看到上一位的清單與寄件匣。
  func reset() {
    list = nil
    outbox = []
    arrival = nil
  }
}
