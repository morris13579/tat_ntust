import SwiftUI
import UIKit

/// 格子選單上的動作，照 `CourseCellAction`。
enum CourseCellAction {
  case moodle, remove, detail, editCourseId
}

/// 點課表格子之後的詳情，照 `course_cell_sheet.dart`：色帶標題、資料、底下的動作。
/// 從學校課表來的課給 Moodle，自己加的課給移除；兩種都有詳細內容。
struct CourseCellSheet: View {
  let cell: CourseGridCell
  let time: String
  let onAction: (CourseCellAction) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var copied = false

  var body: some View {
    SheetStack {
      List {
        // 色帶取格子的顏色，使用者才認得出點到的是哪一格。
        Section { band }
          .listRowInsets(EdgeInsets())
          .listRowBackground(CoursePalette.color(for: cell.order))
        if cell.teacher != nil || !cell.courseId.isEmpty {
          Section { data }
        }
        Section { actions }
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
      }
    }
    .task(id: copied) {
      guard copied else { return }
      try? await Task.sleep(for: .seconds(1.5))
      copied = false
    }
  }

  private var band: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(cell.name)
        .font(.title2.weight(.semibold))
      if cell.classroom != nil || !time.isEmpty {
        HStack(spacing: 12) {
          if let classroom = cell.classroom {
            Text(classroom).font(.headline)
          }
          if !time.isEmpty {
            Text(time).monospacedDigit()
          }
        }
      }
    }
    .foregroundStyle(CoursePalette.bandForeground(for: cell.order))
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
  }

  @ViewBuilder private var data: some View {
    if let teacher = cell.teacher {
      LabeledContent {
        Text(teacher)
      } label: {
        label(Lucide.user, L10n.instructor)
      }
    }
    if !cell.courseId.isEmpty {
      HStack(spacing: 8) {
        label(Lucide.hash, L10n.courseId)
        Spacer(minLength: 8)
        Text(cell.courseId)
          .monospacedDigit()
          .foregroundStyle(.secondary)
        rowButton(copied ? Lucide.check : Lucide.copy, L10n.copy) {
          UIPasteboard.general.string = cell.courseId
          copied = true
        }
        .sensoryFeedback(.success, trigger: copied) { _, now in now }
        rowButton(Lucide.squarePen, L10n.edit) { choose(.editCourseId) }
      }
    }
  }

  /// 並排的兩顆按鈕，不做成清單的列：列看起來不像點得下去。
  private var actions: some View {
    HStack(spacing: 12) {
      if cell.selected {
        actionButton(Lucide.graduationCap, L10n.courseData) { choose(.moodle) }
      } else {
        actionButton(Lucide.trash2, L10n.remove, role: .destructive) { choose(.remove) }
      }
      actionButton(Lucide.fileText, L10n.details) { choose(.detail) }
    }
  }

  private func actionButton(
    _ icon: LucideIcon, _ title: String, role: ButtonRole? = nil, action: @escaping () -> Void
  ) -> some View {
    let color = role == .destructive ? Color(.systemRed) : Color.tatBrand
    return Button(role: role, action: action) {
      Label {
        Text(title)
      } icon: {
        // 自己畫的圖示不吃按鈕的 role，破壞性的按鈕字變紅、圖示卻還是 tint 的藍，要自己上色。
        LucideImage(icon, size: 18).foregroundStyle(color)
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .controlSize(.large)
    .tint(color)
  }

  /// 先交出去再關：呼叫端等 sheet 關掉才開下一個畫面。
  private func choose(_ action: CourseCellAction) {
    onAction(action)
    dismiss()
  }

  private func label(_ icon: LucideIcon, _ title: String) -> some View {
    Label {
      Text(title)
    } icon: {
      LucideImage(icon, size: 20).foregroundStyle(Color.tatBrand)
    }
  }

  private func rowButton(_ icon: LucideIcon, _ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      LucideImage(icon, size: 18)
        .foregroundStyle(Color.tatBrand)
        .frame(width: 36, height: 36)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(label)
  }
}
