import SwiftUI

/// 課表頁的格線：一次放得下九節，超過就捲動，載入時逐列放大淡入。
struct CourseGridView: View {
  let grid: CourseGrid
  var onSelect: (CourseGridCell) -> Void
  /// 點到空堂格，帶著星期與節次的索引。
  var onSelectEmpty: ((Int64, Int64) -> Void)?
  /// 點了空堂格之後要問的事，掛在那一格上。
  var emptyPrompt: EmptyCellPrompt?
  var onDismissPrompt: () -> Void = {}

  @State private var appeared = false

  var body: some View {
    GeometryReader { proxy in
      let rowHeight = max(
        44, (proxy.size.height - CourseGridContent.headerHeight) / CourseGridContent.visibleRows)
      ScrollView {
        CourseGridContent(
          grid: grid, rowHeight: rowHeight, appeared: appeared, onSelect: onSelect, onSelectEmpty: onSelectEmpty,
          emptyPrompt: emptyPrompt, onDismissPrompt: onDismissPrompt)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .task { appeared = true }
  }
}

/// 星期 × 節次的格線本體。課表頁、他人課表與匯出圖片共用。
struct CourseGridContent: View {
  let grid: CourseGrid
  let rowHeight: CGFloat
  /// false 時每一列都藏著，變成 true 時照 Flutter 版的 staggeredList 一列接一列進場。
  var appeared = true
  /// nil 代表唯讀（他人課表、匯出圖片）。
  var onSelect: ((CourseGridCell) -> Void)?
  /// 空堂格點下去做什麼；nil 代表空堂不能點。
  var onSelectEmpty: ((Int64, Int64) -> Void)?
  var emptyPrompt: EmptyCellPrompt?
  var onDismissPrompt: () -> Void = {}

  static let headerHeight: CGFloat = 25
  static let sectionWidth: CGFloat = 22
  static let visibleRows: CGFloat = 9

  private struct Slot: Hashable {
    let day: Int64
    let section: Int64
  }

  var body: some View {
    let cells = Dictionary(
      grid.cells.map { (Slot(day: $0.day, section: $0.section), $0) }
    ) { first, _ in first }
    VStack(spacing: 0) {
      header
        .staggeredAppear(0, appeared)
      ForEach(Array(grid.sections.enumerated()), id: \.element.index) { offset, section in
        row(section, cells: cells)
          .frame(height: rowHeight)
          .background(offset.isMultiple(of: 2) ? Color(.systemBackground) : Color(.secondarySystemBackground))
          .staggeredAppear(offset + 1, appeared)
      }
    }
  }

  private var header: some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: Self.sectionWidth)
      ForEach(grid.days, id: \.index) { day in
        Text(day.label)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
      }
    }
    .frame(height: Self.headerHeight)
  }

  private func row(_ section: CourseGridSection, cells: [Slot: CourseGridCell]) -> some View {
    HStack(spacing: 0) {
      Text(section.label)
        .font(.footnote.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: Self.sectionWidth)
      ForEach(grid.days, id: \.index) { day in
        if let cell = cells[Slot(day: day.index, section: section.index)] {
          if let onSelect {
            Button { onSelect(cell) } label: { block(cell) }
              .buttonStyle(.plain)
              .padding(1.5)
          } else {
            block(cell).padding(1.5)
          }
        } else if let onSelectEmpty {
          Button {
            onSelectEmpty(day.index, section.index)
          } label: {
            Color.clear
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .modifier(
            EmptyCellPromptAnchor(prompt: emptyPrompt, day: day.index, section: section.index, onDismiss: onDismissPrompt))
        } else {
          Color.clear.frame(maxWidth: .infinity)
        }
      }
    }
  }

  private func block(_ cell: CourseGridCell) -> some View {
    Text(cell.name)
      .font(.footnote.weight(.medium))
      .foregroundStyle(CoursePalette.foreground)
      .multilineTextAlignment(.center)
      .lineLimit(3)
      .minimumScaleFactor(0.7)
      .padding(2)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        CoursePalette.color(for: cell.order),
        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}

enum CourseGridExport {
  /// 整週課表的 PNG，照 Flutter 版的匯出圖片：看到什麼就匯出什麼，只是不捲動、每一列固定高。
  @MainActor
  static func png(for grid: CourseGrid) -> Data? {
    let width = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }
      .first ?? 390
    let renderer = ImageRenderer(
      content: CourseGridContent(grid: grid, rowHeight: 56)
        .frame(width: width)
        .background(Color(.systemBackground)))
    renderer.scale = 3
    return renderer.uiImage?.pngData()
  }
}

/// 點了空堂格之後在那一格上跳出來的詢問。
struct EmptyCellPrompt {
  let day: Int64
  let section: Int64
  let title: String
  let message: String
  let actionTitle: String
  let action: () -> Void
}

/// 詢問框掛在點到的那一格上：iOS 26 的詢問框從掛的地方跳出來，掛在整頁的話箭頭會指到別處。
private struct EmptyCellPromptAnchor: ViewModifier {
  let prompt: EmptyCellPrompt?
  let day: Int64
  let section: Int64
  let onDismiss: () -> Void

  func body(content: Content) -> some View {
    let mine = prompt.flatMap { $0.day == day && $0.section == section ? $0 : nil }
    content.confirmationDialog(
      mine?.title ?? "",
      isPresented: Binding(get: { mine != nil }, set: { if !$0 { onDismiss() } }),
      titleVisibility: .visible,
      presenting: mine
    ) { prompt in
      Button(prompt.actionTitle, action: prompt.action)
      Button(L10n.cancel, role: .cancel) {}
    } message: { prompt in
      Text(prompt.message)
    }
  }
}
