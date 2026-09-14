import Observation

@MainActor
@Observable
final class CourseTableModel {
  enum Phase {
    case loading
    case loaded(CourseGrid)
    case failed
  }

  private(set) var phase: Phase = .loading
  private(set) var semesters: [String] = []
  private(set) var isBusy = false
  /// 每載入一次就加一，格線用它重播進場動畫（Flutter 版重新整理也會重播）。
  private(set) var loadCount = 0
  private(set) var myTables: [MyTable] = []
  private(set) var sharedTables: [SharedTableInfo] = []
  private(set) var drafts: [DraftTableInfo] = []
  /// 鈴鐺上的未讀數。
  private(set) var unread: Int64 = 0

  let client: CourseTableClient
  let inbox: InboxClient
  let simulation: SimulationClient
  private var started = false

  init(client: CourseTableClient, inbox: InboxClient, simulation: SimulationClient) {
    self.client = client
    self.inbox = inbox
    self.simulation = simulation
  }

  var grid: CourseGrid? {
    if case .loaded(let grid) = phase { grid } else { nil }
  }

  /// 先顯示上次那一張，沒有才去抓，與 `CourseController._loadSetting` 一致。
  func start() async {
    guard !started else { return }
    started = true
    // 課表出來之後在背景把學期清單抓好，點學期選單時就不用等，照 `CourseController` 的 preloadSemesterList。
    defer { Task { try? await client.preloadSemesters() } }
    if let grid = try? await client.current() {
      phase = .loaded(grid)
      loadCount += 1
      return
    }
    await load(semester: nil, refresh: false)
  }

  func refresh() async {
    await load(semester: grid?.semester, refresh: true)
  }

  func select(semester: String) async {
    guard semester != grid?.semester else { return }
    await load(semester: semester, refresh: false)
  }

  /// 打開選單之前先抓好。清單拿不到時核心可能要問手動選學期，那個對話框得在沒有
  /// sheet 蓋著的時候才開得出來。
  func loadSemesters() async {
    isBusy = true
    defer { isBusy = false }
    if let list = try? await client.semesters() { semesters = list }
  }

  func isCurrent(_ table: MyTable) -> Bool {
    grid?.studentId == table.studentId && grid?.semester == table.semester
  }

  /// 切換器與管理頁的兩份清單。和學期選單一樣，打開 sheet 之前先抓好，sheet 才不會一開就跳高度。
  func loadSwitcher() async {
    if let list = try? await client.myTables() { myTables = list }
    if let list = try? await client.sharedTables() { sharedTables = list }
    if let list = try? await simulation.drafts() { drafts = list }
  }

  func deleteDraft(_ draft: DraftTableInfo) async {
    try? await simulation.deleteDraft(id: draft.id)
    await loadSwitcher()
  }

  /// 回到課表頁時順手更新；一分鐘內不重抓，節流在核心。
  func refreshBadge(force: Bool = false) async {
    if let count = try? await inbox.badge(force: force) { unread = count }
  }

  func apply(_ table: MyTable) async {
    guard !isCurrent(table) else { return }
    isBusy = true
    defer { isBusy = false }
    if let grid = try? await client.applyMyTable(table) {
      phase = .loaded(grid)
      loadCount += 1
    }
  }

  func delete(_ table: MyTable) async {
    try? await client.deleteMyTable(table)
    await loadSwitcher()
  }

  func deleteShared(_ table: SharedTableInfo) async {
    try? await client.deleteSharedTable(id: table.id)
    await loadSwitcher()
  }

  /// 導入其他課程改過課表之後，換成改過的那一張。
  func replace(_ grid: CourseGrid) {
    phase = .loaded(grid)
  }

  func remove(_ cell: CourseGridCell) async {
    isBusy = true
    defer { isBusy = false }
    if let grid = try? await client.removeCourse(cell) { phase = .loaded(grid) }
  }

  func editCourseId(_ cell: CourseGridCell, to courseId: String) async {
    isBusy = true
    defer { isBusy = false }
    if let grid = try? await client.editCourseId(cell, to: courseId) { phase = .loaded(grid) }
  }

  func share() async -> TableShare? {
    try? await client.share()
  }

  private func load(semester: String?, refresh: Bool) async {
    isBusy = true
    defer { isBusy = false }
    let previous = grid
    if previous == nil { phase = .loading }
    if let grid = try? await client.load(semester: semester, refresh: refresh) {
      phase = .loaded(grid)
      loadCount += 1
    } else if previous == nil {
      phase = .failed
    }
    // 失敗但手上有舊的就留著：錯誤對話框核心已經問過了，不必再把課表換成錯誤頁。
  }
}
