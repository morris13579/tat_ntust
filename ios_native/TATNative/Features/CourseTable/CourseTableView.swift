import SwiftUI

/// 內容與流程照 `course_table_page.dart`：學號與學期、格線、點格子看詳情、右上角的課表選項。
struct CourseTableView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: CourseTableModel
  @State private var selected: CourseGridCell?
  @State private var sheet: Sheet?
  /// 同一時間只能開一個 sheet：選單上選了什麼，等它關掉之後才開下一個。
  @State private var afterDismiss: (() -> Void)?
  @State private var path: [Route] = []
  @State private var importing: ImportRequest?
  /// 格子選單上選的動作，等選單關掉才做。
  @State private var cellAction: (cell: CourseGridCell, action: CourseCellAction)?
  @State private var removing: CourseGridCell?
  @State private var editing: CourseGridCell?
  @State private var courseIdDraft = ""
  @State private var emptyCell: EmptyCell?

  private enum Sheet: Identifiable {
    case semesters, switcher, search, scan
    case share(TableShare)
    case draftSemesters([String])

    var id: String {
      switch self {
      case .semesters: "semesters"
      case .switcher: "switcher"
      case .search: "search"
      case .scan: "scan"
      case .share: "share"
      case .draftSemesters: "draftSemesters"
      }
    }
  }

  enum Route: Hashable {
    case manage
    case shared(SharedTableInfo, restore: Bool)
    case detail(CourseRef)
    case moodle(CourseRef)
    case inbox
    case simulation(SimulationState)
    case classroom(date: String, section: Int64)
  }

  private struct ImportRequest: Identifiable {
    let raw: String
    let preview: SharePreview
    var id: String { raw }
  }

  init(model: CourseTableModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    NavigationStack(path: $path) {
      withToolbar(
        content
          .navigationTitle(L10n.titleCourse)
          .navigationBarTitleDisplayMode(.inline)
      )
      .navigationDestination(for: Route.self) { destination($0) }
    }
    .sheet(item: $selected, onDismiss: runCellAction) { cell in
      CourseCellSheet(cell: cell, time: time(of: cell)) { action in
        cellAction = (cell, action)
      }
    }
    .alert(
      removing?.name ?? "",
      isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
      presenting: removing
    ) { cell in
      Button(L10n.remove, role: .destructive) { Task { await model.remove(cell) } }
      Button(L10n.cancel, role: .cancel) {}
    }
    .alert(
      L10n.courseId,
      isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } }),
      presenting: editing
    ) { cell in
      TextField(L10n.courseId, text: $courseIdDraft)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.sure) { Task { await model.editCourseId(cell, to: courseIdDraft) } }
    }
    .sheet(item: $sheet, onDismiss: runAfterDismiss) { sheet in
      sheetContent(sheet)
    }
    .sheet(item: $importing) { request in
      ImportConfirmSheet(preview: request.preview, raw: request.raw, client: model.client) {
        Task { await importTable(request.raw) }
      }
    }
    .task {
      await model.start()
      await model.refreshBadge()
    }
    .onAppear {
      Task { await model.refreshBadge() }
    }
  }

  /// 通知與選單各自一塊：iOS 26 的導覽列會把相鄰的鈕併成同一塊玻璃，要用間隔分開。
  @ViewBuilder private func withToolbar<Content: View>(_ view: Content) -> some View {
    if #available(iOS 26, *) {
      view.toolbar {
        ToolbarItem(placement: .topBarTrailing) { bellButton.toolbarButtonTint() }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) { optionsMenu.toolbarButtonTint() }
      }
    } else {
      view.toolbar {
        ToolbarItem(placement: .topBarTrailing) { bellButton.toolbarButtonTint() }
        ToolbarItem(placement: .topBarTrailing) { optionsMenu.toolbarButtonTint() }
      }
    }
  }

  private var bellButton: some View {
    Button {
      path.append(.inbox)
    } label: {
      LucideImage(Lucide.bell, size: 20)
        .overlay(alignment: .topTrailing) {
          if model.unread > 0 {
            Text(verbatim: model.unread > 99 ? "99+" : "\(model.unread)")
              .font(.caption2.weight(.bold).monospacedDigit())
              .foregroundStyle(.white)
              .padding(.horizontal, 4)
              .frame(minWidth: 16, minHeight: 16)
              .background(Color(.systemRed), in: Capsule())
              .offset(x: 9, y: -7)
          }
        }
    }
    .accessibilityLabel(
      model.unread > 0 ? L10n.notificationUnreadTooltip(String(model.unread)) : L10n.announcementCenter)
  }

  /// 課表右上角的選單，照 `course_options_sheet.dart` 的項目，重新整理也收在這裡。
  private var optionsMenu: some View {
    Menu {
      Button {
        Task { await model.refresh() }
      } label: {
        menuLabel(L10n.refresh, Lucide.refreshCw)
      }
      .disabled(model.isBusy)
      Section {
        Button { handle(.switchTable) } label: { menuLabel(L10n.switchTable, hint: L10n.switchTableHint, Lucide.layers2) }
        Button { handle(.importCourse) } label: { menuLabel(L10n.importCourse, hint: L10n.importCourseHint, Lucide.plus) }
        Button { handle(.scan) } label: { menuLabel(L10n.scanTableTitle, hint: L10n.scanTableHint, Lucide.scanLine) }
      }
      Section {
        Button { handle(.share) } label: { menuLabel(L10n.shareTableTitle, hint: L10n.shareTableHint, Lucide.share2) }
        Button { handle(.exportImage) } label: { menuLabel(L10n.exportImage, hint: L10n.exportImageHint, Lucide.download) }
      }
      .disabled(model.grid == nil)
    } label: {
      LucideImage(Lucide.ellipsis, size: 20)
    }
    .accessibilityLabel(L10n.courseTableOptions)
  }

  /// 系統選單只畫得出 `Image`。副標要是 `Label` 後面的另一個 `Text`：包進 `Label` 裡的第二行會被選單吃掉。
  @ViewBuilder private func menuLabel(_ title: String, hint: String? = nil, _ icon: LucideIcon) -> some View {
    Label {
      Text(title)
    } icon: {
      Image(uiImage: icon.uiImage())
    }
    if let hint { Text(hint) }
  }

  @ViewBuilder private var content: some View {
    switch model.phase {
    case .loading:
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed:
      ContentUnavailableView {
        Label {
          Text(L10n.getCourseError)
        } icon: {
          LucideImage(Lucide.triangleAlert, size: 44)
        }
      } actions: {
        Button(L10n.restart) { Task { await model.refresh() } }
          .prominentButtonStyle()
          .disabled(model.isBusy)
      }
    case .loaded(let grid):
      VStack(spacing: 0) {
        identityBar(grid)
        CourseGridView(
          grid: grid, onSelect: { selected = $0 },
          onSelectEmpty: { day, section in Task { await showEmptySlot(day: day, section: section) } },
          emptyPrompt: emptyPrompt, onDismissPrompt: { emptyCell = nil })
          .id(model.loadCount)
      }
    }
  }

  /// 學號與學期。學號用等寬數字：它是固定長度的識別碼，要能一眼核對。
  private func identityBar(_ grid: CourseGrid) -> some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 2) {
        Text(grid.studentId)
          .font(.body.monospacedDigit().weight(.medium))
        Text(TableText.summary(courses: grid.courseCount, credits: grid.credits))
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        Task {
          await model.loadSemesters()
          if !model.semesters.isEmpty { sheet = .semesters }
        }
      } label: {
        HStack(spacing: 4) {
          Text(grid.semester).monospacedDigit()
          LucideImage(Lucide.chevronDown, size: 16)
            .foregroundStyle(.secondary)
        }
        .font(.subheadline.weight(.medium))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
      }
      .buttonStyle(.borderless)
      .tint(Color(.label))
      .disabled(model.isBusy)
      .accessibilityHint(L10n.selectSemester)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  @ViewBuilder private func sheetContent(_ sheet: Sheet) -> some View {
    switch sheet {
    case .semesters:
      SemesterSheet(model: model)
    case .switcher:
      TableSwitcherSheet(model: model) { choice in afterDismiss = { handle(choice) } }
    case .share(let share):
      ShareTableSheet(share: share, presenter: app.presenter)
    case .draftSemesters(let semesters):
      DraftSemesterSheet(semesters: semesters, current: model.grid?.semester) { semester in
        afterDismiss = { Task { await openDraft(semester: semester) } }
      }
    case .search:
      CourseSearchSheet(model: CourseSearchModel(client: app.courseSearch) { model.replace($0) })
    case .scan:
      NavigationStack {
        ScanTableView { raw in Task { await scanned(raw) } }
          .toolbar { SheetCloseButton(label: L10n.close) { self.sheet = nil } }
      }
      .overlay(ToastOverlay(presenter: app.presenter, inSheet: true))
    }
  }

  @ViewBuilder private func destination(_ route: Route) -> some View {
    switch route {
    case .manage:
      ManageTablesView(model: model) { sheet = .scan }
    case .shared(let info, let restore):
      SharedTableView(model: SharedTableModel(client: model.client, info: info, restore: restore))
    case .detail(let course):
      CourseDetailView(model: CourseDetailModel(client: app.courseDetail, course: course))
    case .moodle(let course):
      CourseMoodleView(model: CourseMoodleModel(client: app.courseMoodle, scoreClient: app.score, course: course))
    case .inbox:
      InboxView(model: InboxModel(client: app.inbox))
    case .classroom(let date, let section):
      ClassroomView(model: ClassroomModel(client: app.classroom, initialDate: date, initialSection: section))
    case .simulation(let state):
      SimulationView(model: SimulationModel(client: app.simulation, state: state))
    }
  }

  private func runCellAction() {
    guard let pending = cellAction else { return }
    cellAction = nil
    let cell = pending.cell
    switch pending.action {
    case .moodle:
      if let course = courseRef(cell) { path.append(.moodle(course)) }
    case .detail:
      if let course = courseRef(cell) { path.append(.detail(course)) }
    case .remove:
      removing = cell
    case .editCourseId:
      courseIdDraft = cell.courseId
      editing = cell
    }
  }

  /// 沒有課號的課查不到任何東西，照 Flutter 版說一句「不支持」。
  private func courseRef(_ cell: CourseGridCell) -> CourseRef? {
    guard !cell.courseId.isEmpty else {
      app.presenter.toast(cell.name + L10n.noSupport)
      return nil
    }
    return CourseRef(courseId: cell.courseId, name: cell.name, semester: model.grid?.semester ?? "")
  }

  private func runAfterDismiss() {
    let action = afterDismiss
    afterDismiss = nil
    action?()
  }

  private func handle(_ option: CourseTableOption) {
    switch option {
    case .switchTable:
      Task {
        await model.loadSwitcher()
        sheet = .switcher
      }
    case .importCourse:
      sheet = .search
    case .scan:
      sheet = .scan
    case .share:
      Task {
        if let share = await model.share() { sheet = .share(share) }
      }
    case .exportImage:
      guard let grid = model.grid, let png = CourseGridExport.png(for: grid) else { return }
      ShareSheet.present(pngData: png, fileName: "tat-course-table.png")
    }
  }

  private func handle(_ choice: TableSwitchChoice) {
    switch choice {
    case .mine(let table):
      Task { await model.apply(table) }
    case .shared(let info):
      path.append(.shared(info, restore: false))
    case .draft(let draft):
      Task {
        if let state = try? await app.simulation.draft(id: draft.id) { path.append(.simulation(state)) }
      }
    case .newDraft:
      Task {
        // 學期清單要打網路，打開 sheet 之前先抓好，sheet 才不會一開就跳高度。
        if let semesters = try? await app.simulation.semesters(), !semesters.isEmpty {
          sheet = .draftSemesters(semesters)
        }
      }
    case .manage:
      path.append(.manage)
    }
  }

  /// 空堂格問要不要找這個時段的空教室，照 `course_table_page.dart` 的 `_showEmptyCell`。
  private func showEmptySlot(day: Int64, section: Int64) async {
    guard sheet == nil, emptyCell == nil, let slot = try? await model.client.emptySlot(day: day, section: section)
    else { return }
    emptyCell = EmptyCell(day: day, section: section, slot: slot)
  }

  /// 點到的空堂格與核心給的說明。
  private struct EmptyCell {
    let day: Int64
    let section: Int64
    let slot: EmptySlot
  }

  /// 空堂格先講清楚點的是哪一格，再給「找這個時段的空教室」，照 `empty_cell_sheet.dart`。
  private var emptyPrompt: EmptyCellPrompt? {
    emptyCell.map { cell in
      EmptyCellPrompt(
        day: cell.day, section: cell.section, title: cell.slot.title, message: cell.slot.subtitle,
        actionTitle: L10n.classroomFromCourseTable
      ) {
        path.append(.classroom(date: cell.slot.date, section: cell.slot.section))
      }
    }
  }

  private func openDraft(semester: String) async {
    guard let state = try? await app.simulation.open(semester: semester) else { return }
    path.append(.simulation(state))
  }

  private func scanned(_ raw: String) async {
    guard importing == nil else { return }
    guard let preview = try? await model.client.previewShareCode(raw) else {
      app.presenter.toast(L10n.scanTableInvalid, kind: .error)
      return
    }
    let request = ImportRequest(raw: raw, preview: preview)
    guard sheet != nil else {
      importing = request
      return
    }
    // 掃描頁是 sheet：先收掉它，確認頁才開得出來。
    afterDismiss = { importing = request }
    sheet = nil
  }

  /// 先存再開：格子當下就對了，課名與教室進到那一頁才補。
  private func importTable(_ raw: String) async {
    guard let info = try? await model.client.importShareCode(raw) else { return }
    app.presenter.toast(L10n.importDone(info.label), kind: .success)
    path = [.shared(info, restore: true)]
  }

  private func time(of cell: CourseGridCell) -> String {
    model.grid?.sections.first { $0.index == cell.section }?.time ?? ""
  }
}

enum CourseTableOption {
  case switchTable, importCourse, scan, share, exportImage
}
