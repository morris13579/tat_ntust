import SwiftUI

@MainActor
@Observable
final class ForumModel {
  private(set) var discussions: ForumDiscussions?
  var web: WebPage?
  var thread: ForumThreadRoute?
  let client: CourseMoodleClient
  let course: CourseRef
  let forumId: Int64
  let moduleId: Int64
  let name: String

  init(client: CourseMoodleClient, course: CourseRef, forumId: Int64, moduleId: Int64, name: String) {
    self.client = client
    self.course = course
    self.forumId = forumId
    self.moduleId = moduleId
    self.name = name
  }

  func load() async {
    discussions =
      (try? await client.forumDiscussions(forumId: forumId))
      ?? ForumDiscussions(entries: [], error: L10n.unknownError, signedIn: true)
  }

  func openInWeb() async {
    guard let link = try? await client.moduleWebLink(courseId: course.courseId, moduleId: moduleId) else { return }
    show(link, title: name)
  }

  func openDiscussion(_ row: ForumRow) {
    thread = ForumThreadRoute(discussionId: row.discussionId, title: row.name)
  }

  private func show(_ link: WebLink, title: String) {
    guard let url = URL(string: link.url) else { return }
    web = WebPage(title: title, url: url, fallbackURL: link.fallbackUrl.flatMap(URL.init(string:)))
  }
}

/// 一個討論區的主題清單，照 `course_forum_page.dart`。
struct ForumView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: ForumModel

  init(model: ForumModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        content
      }
      .padding(EdgeInsets(top: 12, leading: 16, bottom: 32, trailing: 16))
    }
    .background(Color(.systemGroupedBackground))
    .refreshable { await model.load() }
    .navigationTitle(model.name)
    .analyticsScreen("/CourseForumPage")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task { await model.openInWeb() }
        } label: {
          LucideImage(Lucide.externalLink, size: 18)
        }
        .accessibilityLabel(L10n.forumOpenInWeb)
        .toolbarButtonTint()
      }
    }
    .browserSheet(item: Binding(get: { model.web }, set: { model.web = $0 })) { url in
      (try? await model.client.isAutologinScript(url: url.absoluteString)) ?? false
    }
    .navigationDestination(item: Binding(get: { model.thread }, set: { model.thread = $0 })) { route in
      ForumThreadView(
        model: ForumThreadModel(
          client: app.forum, moodle: model.client, course: model.course, forumId: model.forumId,
          discussionId: route.discussionId, title: route.title, readOnly: false
        ) {
          Task { await model.load() }
        })
    }
    .task {
      if model.discussions == nil { await model.load() }
    }
  }

  @ViewBuilder private var content: some View {
    if let discussions = model.discussions {
      if let notice = discussions.notice {
        NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh) {
          Task { await model.load() }
        }
        .clipShape(ListGroupShape.card)
        .padding(.bottom, 10)
      }
      if let error = discussions.error, discussions.entries.isEmpty {
        InlineErrorView(message: error, signedIn: discussions.signedIn, presenter: app.presenter) {
          await model.load()
        }
      } else if discussions.entries.isEmpty {
        SectionEmptyState(message: L10n.forumEmpty, icon: Lucide.messagesSquare)
      } else {
        ForumEntryList(entries: discussions.entries) { row in
          model.openDiscussion(row)
        }
      }
    } else {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
  }
}

struct ForumThreadRoute: Hashable {
  let discussionId: Int64
  let title: String
}
