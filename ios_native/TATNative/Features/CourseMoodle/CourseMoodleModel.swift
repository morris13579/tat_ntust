import Observation
import UIKit

@MainActor
@Observable
final class CourseMoodleModel {
  enum Tab: Int, CaseIterable, Identifiable {
    case files, announcements, score, assignments
    var id: Int { rawValue }
  }

  /// 從分頁點進去的畫面。只有一格：同一時間只會推一頁。
  enum Destination: Hashable {
    case folder(moduleId: Int64, title: String)
    case page(moduleId: Int64, title: String)
    case forum(forumId: Int64, moduleId: Int64, name: String)
    case assignment(assignId: Int64, name: String)
    case quiz(quizId: Int64, name: String)
    case thread(discussionId: Int64, forumId: Int64, title: String, readOnly: Bool)
  }

  var tab: Tab = .files
  var destination: Destination?
  /// 內文裡的網頁連結開成瀏覽器 sheet，不佔「推一頁」的那一格。
  var web: WebPage?
  private(set) var directory: CourseDirectory?
  var query = ""
  private(set) var searchResults: [CourseSectionItem] = []
  private(set) var feed: CourseFeed?
  private(set) var feedEntries: [FeedEntry] = []
  private(set) var feedFilter: FeedKind?
  private(set) var assignments: AssignmentList?

  let course: CourseRef
  let client: CourseMoodleClient
  let score: CourseScoreModel
  private var started = false

  init(client: CourseMoodleClient, scoreClient: ScoreClient, course: CourseRef) {
    self.client = client
    self.course = course
    score = CourseScoreModel(
      client: scoreClient,
      course: MoodleGradeCourse(courseId: course.courseId, name: course.name, grade: ""))
  }

  /// 四個分頁一起抓，不等使用者滑過去，照 `CourseDataController.loadAll`。
  func start() async {
    guard !started else { return }
    started = true
    async let files: Void = loadDirectory()
    async let announcements: Void = loadFeed()
    async let grades: Void = score.load()
    async let homework: Void = loadAssignments()
    _ = await (files, announcements, grades, homework)
  }

  func loadDirectory() async {
    let fetched = try? await client.directory(courseId: course.courseId)
    directory =
      fetched
      ?? CourseDirectory(
        weekly: false, stats: "", sections: [], emptySections: [], error: L10n.unknownError, signedIn: true)
    await search()
  }

  func search() async {
    let text = query.trimmingCharacters(in: .whitespaces)
    guard !text.isEmpty else {
      searchResults = []
      return
    }
    searchResults = (try? await client.searchDirectory(courseId: course.courseId, query: text)) ?? []
  }

  func loadFeed() async {
    let fetched = try? await client.feed(courseId: course.courseId)
    let result =
      fetched
      ?? CourseFeed(
        entries: [], announcementCount: 0, discussionCount: 0, emptyMessage: L10n.nothingHere,
        error: L10n.unknownError, signedIn: true)
    feed = result
    feedFilter = nil
    feedEntries = result.entries
  }

  func filterFeed(_ kind: FeedKind?) async {
    guard kind != feedFilter else { return }
    feedFilter = kind
    if let filtered = try? await client.filterFeed(courseId: course.courseId, kind: kind) {
      feedEntries = filtered.entries
    }
  }

  /// 先畫清單，狀態背景抓完再換一次：每一份作業都要各打一趟，等全部回來才畫太久。
  func loadAssignments() async {
    let fetched = try? await client.assignments(courseId: course.courseId)
    let list = fetched ?? AssignmentList(rows: [], summary: "", error: L10n.unknownError, signedIn: true)
    assignments = list
    guard !list.rows.isEmpty, let updated = try? await client.assignmentStatuses(courseId: course.courseId)
    else { return }
    assignments = AssignmentList(
      rows: updated.rows, summary: updated.summary, error: list.error, notice: list.notice,
      signedIn: updated.signedIn)
  }

  func openAssignment(_ row: AssignmentRow) {
    destination = .assignment(assignId: row.id, name: row.name)
  }

  /// 作業詳情頁寫進伺服器之後，清單照手上的狀態重排，不打網路。
  func reloadCachedAssignments() async {
    guard let current = assignments, let list = try? await client.cachedAssignments(courseId: course.courseId)
    else { return }
    assignments = AssignmentList(
      rows: list.rows, summary: list.summary, error: current.error, notice: current.notice,
      signedIn: list.signedIn)
  }

  /// 點課程模組，照 `CourseModuleActions.handle`。
  func open(_ module: CourseModuleItem, presenter: UiPresenter) async {
    switch module.kind {
    case .resource, .other:
      let link = try? await client.moduleFile(courseId: course.courseId, moduleId: module.id)
      await MoodleFiles.open(link, folder: course.name, presenter: presenter)
    case .url:
      guard let raw = try? await client.moduleUrl(courseId: course.courseId, moduleId: module.id),
        let url = URL(string: raw)
      else {
        presenter.toast(L10n.nothingHere)
        return
      }
      await UIApplication.shared.open(url)
    case .page:
      destination = .page(moduleId: module.id, title: module.name)
    case .folder:
      destination = .folder(moduleId: module.id, title: module.name)
    case .forum:
      destination = .forum(forumId: module.instance, moduleId: module.id, name: module.name)
    case .assign:
      destination = .assignment(assignId: module.instance, name: module.name)
    case .quiz:
      destination = .quiz(quizId: module.instance, name: module.name)
    case .label:
      break
    }
  }

  func openDiscussion(_ row: ForumRow) {
    // 公告區對學生是唯讀的（`replynews` 只給老師），網頁版也一樣，所以那裡不掛「去網頁回覆」。
    destination = .thread(
      discussionId: row.discussionId, forumId: row.forumId, title: row.name, readOnly: row.kind == .announcement)
  }

  /// HTML 裡的連結：自家檔案直接下載、網頁在 App 內開，照 `MoodleHtmlView`。
  func openLink(_ url: URL, presenter: UiPresenter) async {
    guard let target = try? await client.linkTarget(url: url.absoluteString) else { return }
    switch target.kind {
    case .download:
      await MoodleFiles.open(
        MoodleFileLink(name: target.filename ?? "", url: target.url), folder: course.name, presenter: presenter)
    case .web:
      show(WebLink(url: target.url, fallbackUrl: target.fallbackUrl), title: course.name)
    case .blocked:
      break
    }
  }

  private func show(_ link: WebLink, title: String) {
    guard let url = URL(string: link.url) else { return }
    web = WebPage(title: title, url: url, fallbackURL: link.fallbackUrl.flatMap(URL.init(string:)))
  }
}

/// 下載 Moodle 檔案並打開，照 `FileDownload.download`：下載過的直接開。
@MainActor
enum MoodleFiles {
  static func open(_ link: MoodleFileLink?, folder: String, presenter: UiPresenter) async {
    guard let link, let url = URL(string: link.url) else {
      presenter.toast(L10n.nothingHere)
      return
    }
    if let cached = FileDownloads.cached(name: link.name, folder: folder) {
      FileDownloads.preview(cached)
      return
    }
    let file = await DownloadFeedback.run(name: link.name, presenter: presenter) { progress in
      try await FileDownloads.download(url, name: link.name, folder: folder, progress: progress)
    }
    if let file { FileDownloads.preview(file) }
  }
}

extension StatusTone {
  var pill: PillTone {
    switch self {
    case .pending: .pending
    case .submitted: .submitted
    case .draft: .draft
    case .attention: .attention
    case .graded: .graded
    case .overdue: .overdue
    }
  }
}

/// `FileIconUtils` 的檔案類型換成 Lucide 的圖示。
enum MoodleFileIcon {
  static func of(_ name: String?) -> LucideIcon {
    switch name {
    case "pdf", "document", "writer", "text", "publisher": Lucide.fileText
    case "image", "gif", "psd", "eps", "draw", "isf": Lucide.fileImage
    case "video", "flash": Lucide.fileVideo2
    case "audio": Lucide.fileMusic
    case "archive": Lucide.fileArchive
    case "spreadsheet", "calc", "chart", "database": Lucide.fileSpreadsheet
    case "powerpoint", "impress": Lucide.presentation
    case "sourcecode", "markup", "math": Lucide.fileCode
    case "epub": Lucide.bookOpen
    case "h5p", "moodle": Lucide.fileBox
    default: Lucide.file
    }
  }
}
