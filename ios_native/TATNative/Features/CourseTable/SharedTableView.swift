import Observation
import SwiftUI

@MainActor
@Observable
final class SharedTableModel {
  let info: SharedTableInfo
  private(set) var grid: CourseGrid?
  private(set) var isRestoring = false

  private let client: CourseTableClient
  private let restore: Bool

  init(client: CourseTableClient, info: SharedTableInfo, restore: Bool) {
    self.client = client
    self.info = info
    self.restore = restore
  }

  /// 格子先畫出來（分享碼帶了時間），剛匯入的才去補課名。
  func start() async {
    grid = try? await client.sharedTable(id: info.id)
    guard restore else { return }
    isRestoring = true
    defer { isRestoring = false }
    if let restored = try? await client.restoreSharedTable(id: info.id) { grid = restored }
  }
}

/// 掃進來的他人課表，照 `shared_table_page.dart`。唯讀，而且掛一個「他人」的記號：
/// 它跟自己的課表長得一樣，沒有記號會看錯成自己的。
struct SharedTableView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: SharedTableModel

  init(model: SharedTableModel) {
    _model = State(initialValue: model)
  }

  /// Dart 報補課名進度用的 key，同 `CourseTableBridge.restoreSharedTable`。
  private var restoreKey: String { "restore-\(model.info.id)" }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 10) {
          Text(L10n.sharedTableBadge)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
          Text("\(model.info.semester) · \(L10n.courseCount(String(model.info.courseCount)))")
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        // 補課名的進度，照 Flutter 版：格子已經在了，所以只是一行字。
        if model.isRestoring, let label = app.transfers.progress[restoreKey]?.label {
          Text(label)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
        }
        // 跟自己的課表同一個格線：高度照畫面分，不會在底下留一截空白。
        if let grid = model.grid {
          CourseGridView(grid: grid, onSelect: { _ in })
        } else {
          Spacer()
        }
    }
    .padding(.top, 4)
    .navigationTitle(model.info.label)
    .analyticsScreen("/SharedTablePage")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await model.start()
      app.transfers.clear(restoreKey)
    }
  }
}
