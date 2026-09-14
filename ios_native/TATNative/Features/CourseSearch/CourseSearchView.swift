import SwiftUI

/// 導入其他課程，照 `course_search_page.dart`：搜尋列、三個篩選籤、每門課一列。
/// 每一列都寫出會跟哪一門衝堂，不必加完回課表才發現排不下。
struct CourseSearchView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: CourseSearchModel
  @State private var showFilter = false
  @State private var showSlots = false

  init(model: CourseSearchModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    List {
      if case .loaded(let results) = model.phase, !results.courses.isEmpty {
        ForEach(results.courses, id: \.id) { row($0) }
      }
    }
    .listStyle(.plain)
    .overlay { placeholder.allowsHitTesting(false) }
    .pinnedTopBar { header }
    .searchable(
      text: $model.keyword, placement: .navigationBarDrawer(displayMode: .always),
      prompt: L10n.search
    )
    .autocorrectionDisabled()
    .onSubmit(of: .search) { Task { await model.submit() } }
    .navigationTitle(L10n.courseSearchTitle)
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(isPresented: $showFilter) {
      CourseFilterView(filter: model.filter, client: model.client) { next in
        Task { await model.apply(next) }
      }
    }
    .navigationDestination(isPresented: $showSlots) {
      if let start = model.start {
        SlotPickerView(days: start.days, sections: start.sections, selected: model.slots) { next in
          Task { await model.setSlots(next) }
        }
      }
    }
    .task { await model.begin() }
    .analyticsScreen("/CourseSearchPage")
  }

  /// 篩選籤與結果摘要釘在搜尋列下面，不跟著結果捲走。摘要不做成分段標題：標題自帶的上下留白會把兩者隔很開。
  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      chips
      if case .loaded(let results) = model.phase, !results.courses.isEmpty {
        Text(summary(results))
          .font(.footnote.monospacedDigit())
          .foregroundStyle(.secondary)
          .padding(.horizontal, 16)
      }
    }
    .padding(.top, 4)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var chips: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        FilterChip(
          label: L10n.courseSearchFilter, icon: Lucide.filter, isOn: model.filter.hasRefinements
        ) {
          showFilter = true
        }
        FilterChip(label: L10n.courseSearchHideConflict, isOn: model.hideConflict) {
          Task { await model.setHideConflict(!model.hideConflict) }
        }
        FilterChip(label: L10n.courseSearchSlot, isOn: !model.slots.isEmpty) {
          showSlots = true
        }
        .disabled(model.start == nil)
      }
    }
    // 籤可以左右捲到螢幕邊，靜止時跟下面的字對齊。
    .contentMargins(.horizontal, 16, for: .scrollContent)
    .scrollIndicators(.hidden)
  }

  private func row(_ course: SearchCourse) -> some View {
    HStack(alignment: .center, spacing: 8) {
      VStack(alignment: .leading, spacing: 3) {
        Text(course.name)
        Text(meta(course))
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
        if let detail = detail(course) {
          Text(detail)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        ForEach(Array(course.conflicts.enumerated()), id: \.offset) { _, conflict in
          HStack(alignment: .top, spacing: 6) {
            LucideImage(Lucide.triangleAlert, size: 14)
              .padding(.top, 1)
            Text(L10n.courseSearchConflictWith(conflict.courseName, conflict.slots))
          }
          .font(.footnote)
          .foregroundStyle(Color(.systemRed))
          .padding(.top, 2)
        }
      }
      Spacer(minLength: 0)
      toggle(course)
    }
    .padding(.vertical, 4)
  }

  private func toggle(_ course: SearchCourse) -> some View {
    let busy = model.pending.contains(course.id)
    return Button {
      Task {
        let applied = await model.toggle(course)
        if !applied { app.presenter.toast(L10n.addCustomCourseError, kind: .error) }
      }
    } label: {
      ZStack {
        if busy {
          ProgressView()
        } else {
          LucideImage(course.added ? Lucide.check : Lucide.plus, size: 22)
            .foregroundStyle(Color.tatBrand)
        }
      }
      .frame(width: 44, height: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .disabled(busy)
    .accessibilityLabel(
      model.draftId == nil
        ? (course.added ? L10n.importCourseRemove : L10n.importCourseAdd)
        : (course.added ? L10n.simulationRemoveCourse : L10n.courseSearchAdd))
    .sensoryFeedback(.selection, trigger: course.added)
  }

  /// 「AC5009701 · 3 學分 · 選修」。
  private func meta(_ course: SearchCourse) -> String {
    [course.id, course.credits.map(L10n.creditCount), course.requirement.map(CourseSearchText.requirement)]
      .compactMap { $0 }
      .joined(separator: " · ")
  }

  /// 「王大明 · 三 8　四 3·4 · TR-313」。
  private func detail(_ course: SearchCourse) -> String? {
    let parts = [course.teacher, course.slots, course.classroom].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  /// 「18 門 · 其中 11 門與課表衝堂」，第二段只有真的有衝堂時才出現。
  private func summary(_ results: CourseSearchResults) -> String {
    var parts = [L10n.courseSearchResultSummary(String(results.total))]
    if results.clashes > 0 {
      parts.append(L10n.courseSearchConflictSummary(String(results.clashes)))
    }
    return parts.joined(separator: " · ")
  }

  @ViewBuilder private var placeholder: some View {
    switch model.phase {
    case .idle:
      empty(L10n.courseSearchTitle)
    case .loading:
      ProgressView()
    case .loaded(let results) where results.courses.isEmpty:
      empty(L10n.courseSearchNotFound)
    case .loaded:
      EmptyView()
    }
  }

  private func empty(_ message: String) -> some View {
    ContentUnavailableView {
      Label {
        Text(message)
      } icon: {
        LucideImage(Lucide.search, size: 44)
      }
    }
  }
}

/// 搜尋課程的 sheet，課表的導入課程與模擬排課共用。
struct CourseSearchSheet: View {
  @Environment(AppEnvironment.self) private var app
  @Environment(\.dismiss) private var dismiss
  let model: CourseSearchModel

  var body: some View {
    NavigationStack {
      CourseSearchView(model: model)
        .toolbar { SheetCloseButton(label: L10n.close) { dismiss() } }
    }
    .overlay(ToastOverlay(presenter: app.presenter, inSheet: true))
  }
}
