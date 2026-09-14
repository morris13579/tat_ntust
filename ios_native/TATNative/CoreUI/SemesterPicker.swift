import SwiftUI

/// 手動挑學期：課表的三個學期來源都沒有回答、或存到的學期壞掉時的最後手段。
/// 選項照 Flutter 版的 `manualSemesterDialog`：100–120 學年各三期（H 是暑修），現在這一期排第一。
struct SemesterPicker: View {
  let request: SemesterRequest
  @Environment(\.dismiss) private var dismiss
  private let current = ManualSemester.current()

  var body: some View {
    SheetStack(title: L10n.selectSemester) {
      List {
        ForEach(ManualSemester.options(startingAt: current), id: \.self) { option in
          CheckRow(label: option, tabularFigures: true, isSelected: option == current) {
            request.finish(option)
            dismiss()
          }
        }
      }
    }
    // 往下滑、點 ✕ 都要回答，否則核心那一端永遠等不到。
    .onDisappear { request.finish(fallback) }
  }

  /// allowNull 為 false 時沒選就回現在這一期，與 manualSemesterDialog 一致。
  private var fallback: String? { request.allowNull ? nil : current }
}

enum ManualSemester {
  static func current(_ date: Date = .now) -> String {
    let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
    let month = parts.month ?? 1
    let year = (parts.year ?? 1911) - 1911 - (month <= 7 ? 1 : 0)
    return "\(year)-\(month <= 7 ? 2 : 1)"
  }

  static func options(startingAt current: String) -> [String] {
    let all = (100...120).reversed().flatMap { year in ["H", "2", "1"].map { "\(year)-\($0)" } }
    guard let index = all.firstIndex(of: current) else { return [current] + all }
    return Array(all[index...] + all[..<index])
  }
}
