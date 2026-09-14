import SwiftUI

/// 模擬排課，照 `simulation_page.dart`：草稿是另一份課表，不會寫回實際課表。實際課表與草稿畫在同一張格線上，
/// 撞在一起的格子標紅；底下是摘要與搜尋課程。
struct SimulationView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: SimulationModel
  @State private var showCourses = false
  @State private var searching = false
  @State private var removing: DraftTap?

  init(model: SimulationModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    VStack(spacing: 0) {
      if let banner = model.state.conflictBanner {
        NoticeBar(message: banner, kind: .error)
      }
      ScrollView {
        SimulationGrid(
          state: model.state,
          removing: removing,
          onRemove: { course in Task { await model.remove(courseId: course.id) } },
          onDismissRemove: { removing = nil },
          onTapDraft: { removing = $0 }
        )
          .padding(EdgeInsets(top: 8, leading: 8, bottom: 16, trailing: 8))
      }
    }
    .pinnedBottomBar { summaryBar }
    .navigationTitle(model.state.label)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        VStack(spacing: 1) {
          Text(model.state.label).font(.headline)
          Text(L10n.simulationSubtitle).font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .sheet(isPresented: $searching, onDismiss: { Task { await model.reload() } }) {
      CourseSearchSheet(model: CourseSearchModel(client: app.courseSearch, draftId: model.draftId) { _ in })
    }
    .sheet(isPresented: $showCourses) { DraftCoursesSheet(model: model) }
    .analyticsScreen("/SimulationPage")
  }

  /// 「草稿本身多少」與「加上實際課表之後多少」分成兩行：前者是這一頁的產出，後者是使用者真正要問的問題。
  private var summaryBar: some View {
    VStack(spacing: 10) {
      Button {
        showCourses = true
      } label: {
        HStack(spacing: 10) {
          LucideImage(Lucide.flaskConical, size: 18).foregroundStyle(.secondary)
          VStack(alignment: .leading, spacing: 2) {
            Text(model.state.draftSummary)
              .font(.subheadline.weight(.semibold).monospacedDigit())
            Text(model.state.detail)
              .font(.footnote.monospacedDigit())
              .foregroundStyle(model.state.hasConflicts ? Color(.systemRed) : .secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          LucideImage(Lucide.chevronUp, size: 18).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityHint(L10n.simulationDraftListTitle)
      Button {
        searching = true
      } label: {
        Label {
          Text(L10n.courseSearchTitle)
        } icon: {
          LucideImage(Lucide.search, size: 18)
        }
        .frame(maxWidth: .infinity)
      }
      .prominentButtonStyle()
      .controlSize(.large)
    }
    .padding(EdgeInsets(top: 10, leading: 16, bottom: 12, trailing: 16))
  }
}

/// 模擬課表的格線，照 `simulation_table.dart`：實際課表是實心色塊、草稿是虛線框加淡底，
/// 衝堂的格子紅框上下擺兩門——只畫一門的話看不出是跟誰撞。
struct SimulationGrid: View {
  let state: SimulationState
  /// 等著確認要不要移除的那一格。
  var removing: DraftTap?
  var onRemove: (SimCourse) -> Void = { _ in }
  var onDismissRemove: () -> Void = {}
  let onTapDraft: (DraftTap) -> Void

  /// 固定列高：這一頁是整週捲動看的，不像主課表要塞滿一屏。
  private static let rowHeight: CGFloat = 56

  private struct Slot: Hashable {
    let day: Int64
    let section: Int64
  }

  var body: some View {
    let cells = Dictionary(state.cells.map { (Slot(day: $0.day, section: $0.section), $0) }) { first, _ in first }
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        Color.clear.frame(width: CourseGridContent.sectionWidth)
        ForEach(state.days, id: \.index) { day in
          Text(day.label)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
      }
      .frame(height: CourseGridContent.headerHeight)
      ForEach(Array(state.sections.enumerated()), id: \.element.index) { offset, section in
        HStack(spacing: 0) {
          Text(section.label)
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: CourseGridContent.sectionWidth)
          ForEach(state.days, id: \.index) { day in
            cell(cells[Slot(day: day.index, section: section.index)])
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .padding(1.5)
          }
        }
        .frame(height: Self.rowHeight)
        .background(offset.isMultiple(of: 2) ? Color(.systemBackground) : Color(.secondarySystemBackground))
      }
    }
  }

  @ViewBuilder private func cell(_ cell: SimCell?) -> some View {
    if let cell, cell.conflict, let real = cell.real, let draft = cell.draft {
      let tap = DraftTap(course: draft, day: cell.day, section: cell.section)
      VStack(spacing: 0) {
        mini(real.name)
        Button {
          onTapDraft(tap)
        } label: {
          mini(draft.name)
        }
        .buttonStyle(.plain)
        .modifier(RemoveDraftPrompt(tap: tap, removing: removing, onRemove: onRemove, onDismiss: onDismissRemove))
      }
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(Color(.systemRed), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
    } else if let cell, let draft = cell.draft {
      let tap = DraftTap(course: draft, day: cell.day, section: cell.section)
      Button {
        onTapDraft(tap)
      } label: {
        block(draft, isDraft: true)
      }
      .buttonStyle(.plain)
      .modifier(RemoveDraftPrompt(tap: tap, removing: removing, onRemove: onRemove, onDismiss: onDismissRemove))
    } else if let real = cell?.real {
      block(real, isDraft: false)
    } else {
      Color.clear
    }
  }

  private func block(_ course: SimCourse, isDraft: Bool) -> some View {
    return Text(course.name)
      .font(.footnote.weight(.medium))
      .foregroundStyle(CoursePalette.foreground)
      .multilineTextAlignment(.center)
      .lineLimit(3)
      .minimumScaleFactor(0.7)
      .padding(2)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        isDraft ? CoursePalette.draftColor(for: course.order) : CoursePalette.color(for: course.order),
        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
      )
      .overlay {
        if isDraft {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(CoursePalette.foreground.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
        }
      }
  }

  private func mini(_ name: String) -> some View {
    Text(name)
      .font(.caption2)
      .foregroundStyle(Color(.systemRed))
      .multilineTextAlignment(.center)
      .lineLimit(2)
      .minimumScaleFactor(0.7)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
  }
}

/// 點到的草稿課與它所在的格子：同一門課會占好幾格，確認要從點到的那一格跳出來。
struct DraftTap: Equatable {
  let course: SimCourse
  let day: Int64
  let section: Int64
}

/// 格子上點一下就刪太容易誤觸，先問一次；詢問框掛在那一格上，iOS 26 從掛的地方跳出來。
private struct RemoveDraftPrompt: ViewModifier {
  let tap: DraftTap
  let removing: DraftTap?
  let onRemove: (SimCourse) -> Void
  let onDismiss: () -> Void

  func body(content: Content) -> some View {
    content.confirmationDialog(
      tap.course.name,
      isPresented: Binding(get: { removing == tap }, set: { if !$0 { onDismiss() } }),
      titleVisibility: .visible
    ) {
      Button(L10n.simulationRemoveCourse, role: .destructive) { onRemove(tap.course) }
      Button(L10n.cancel, role: .cancel) {}
    }
  }
}
