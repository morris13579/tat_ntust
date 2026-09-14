import SwiftUI

/// 行事曆的待辦要推進去的課程模組頁。
struct ModuleRoute: Hashable {
  let course: CourseRef
  let destination: CourseMoodleModel.Destination
}

/// 課程 Moodle 裡推進去的那一頁。課程頁的分頁與行事曆的待辦共用。
struct MoodleDestinationView: View {
  @Environment(AppEnvironment.self) private var app
  let destination: CourseMoodleModel.Destination
  let course: CourseRef
  /// 作業頁寫進伺服器之後，課程頁的作業清單要重排。
  var onAssignmentsChanged: () -> Void = {}
  /// 討論串的第一篇改了或刪了，課程頁的公告清單要重抓。
  var onFeedChanged: () -> Void = {}

  var body: some View {
    let client = app.courseMoodle
    switch destination {
    case .folder(let moduleId, let title):
      CourseFolderView(client: client, course: course, moduleId: moduleId, path: "/", title: title)
    case .page(let moduleId, let title):
      CoursePageView(client: client, course: course, moduleId: moduleId, title: title)
    case .forum(let forumId, let moduleId, let name):
      ForumView(model: ForumModel(client: client, course: course, forumId: forumId, moduleId: moduleId, name: name))
    case .assignment(let assignId, let name):
      AssignmentDetailView(
        model: AssignmentDetailModel(
          client: app.assignment, moodle: client, course: course, assignId: assignId, name: name,
          onChanged: onAssignmentsChanged))
    case .quiz(let quizId, let name):
      QuizDetailView(
        model: QuizDetailModel(client: app.quiz, moodle: client, course: course, quizId: quizId, name: name))
    case .thread(let discussionId, let forumId, let title, let readOnly):
      ForumThreadView(
        model: ForumThreadModel(
          client: app.forum, moodle: client, course: course, forumId: forumId,
          discussionId: discussionId, title: title, readOnly: readOnly, onListChanged: onFeedChanged))
    }
  }
}

extension CourseMoodleModel.Destination {
  /// 行事曆的待辦只會帶作業、測驗、討論區進來（`UpcomingEventUtils.inAppModules`）。
  static func of(_ module: CourseModuleItem) -> Self? {
    switch module.kind {
    case .assign: .assignment(assignId: module.instance, name: module.name)
    case .quiz: .quiz(quizId: module.instance, name: module.name)
    case .forum: .forum(forumId: module.instance, moduleId: module.id, name: module.name)
    default: nil
    }
  }
}
