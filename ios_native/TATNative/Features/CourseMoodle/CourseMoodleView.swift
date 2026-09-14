import SwiftUI

/// 一門課的 Moodle，照 `course_data_page.dart`：檔案、公告、成績、作業四個分頁，可以左右滑。
struct CourseMoodleView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: CourseMoodleModel

  init(model: CourseMoodleModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    VStack(spacing: 0) {
      tabs
      TabView(selection: Binding(get: { model.tab }, set: { model.tab = $0 })) {
        CourseDirectoryView(model: model)
          .tag(CourseMoodleModel.Tab.files)
        CourseFeedView(model: model)
          .tag(CourseMoodleModel.Tab.announcements)
        CourseScoreContent(model: model.score)
          .tag(CourseMoodleModel.Tab.score)
        CourseAssignmentsView(model: model)
          .tag(CourseMoodleModel.Tab.assignments)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .extendsUnderBars()
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle(model.course.name)
    .analyticsScreen("/CourseDataPage")
    .navigationBarTitleDisplayMode(.inline)
    .browserSheet(item: Binding(get: { model.web }, set: { model.web = $0 })) { url in
      (try? await model.client.isAutologinScript(url: url.absoluteString)) ?? false
    }
    .navigationDestination(item: Binding(get: { model.destination }, set: { model.destination = $0 })) {
      destination($0)
    }
    .environment(
      \.openURL,
      OpenURLAction { url in
        Task { await model.openLink(url, presenter: app.presenter) }
        return .handled
      }
    )
    .task { await model.start() }
  }

  private var tabs: some View {
    Picker(selection: Binding(get: { model.tab }, set: { model.tab = $0 })) {
      ForEach(CourseMoodleModel.Tab.allCases) { tab in
        Text(title(tab)).tag(tab)
      }
    } label: {
      EmptyView()
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Color(.systemGroupedBackground))
  }

  private func title(_ tab: CourseMoodleModel.Tab) -> String {
    switch tab {
    case .files: L10n.file
    case .announcements: L10n.announcement
    case .score: L10n.score
    case .assignments: L10n.assignment
    }
  }

  private func destination(_ destination: CourseMoodleModel.Destination) -> some View {
    MoodleDestinationView(
      destination: destination, course: model.course,
      onAssignmentsChanged: { Task { await model.reloadCachedAssignments() } },
      onFeedChanged: { Task { await model.loadFeed() } })
  }
}
