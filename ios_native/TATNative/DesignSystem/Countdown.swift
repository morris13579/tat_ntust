import Foundation

enum Countdown {
  /// 秒數 → 顯示字串，同 `MoodleAssignAttemptUtils.formatDuration`：超過一小時是 H:MM:SS，否則 MM:SS。
  static func format(_ seconds: Int) -> String {
    let total = max(0, seconds)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let rest = total % 60
    return hours > 0
      ? String(format: "%d:%02d:%02d", hours, minutes, rest)
      : String(format: "%02d:%02d", minutes, rest)
  }
}
