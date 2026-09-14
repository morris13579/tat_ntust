import SwiftUI

/// 信件清單，照 `mail_list_page.dart`：標題是資料夾名，寄件匣有東西時排在最上面，信依今天、本週、更早分組，
/// 捲到底自己載下一頁。搜尋交給系統的搜尋列，範圍是目前資料夾或全部資料夾。
struct MailListView: View {
  @Environment(AppEnvironment.self) private var app
  @Bindable var model: MailListModel
  let onOpen: (MailRow) -> Void
  let onCompose: () -> Void
  @State private var sheet: Sheet?
  @State private var afterDismiss: (() -> Void)?
  @State private var discarding: MailOutboxRow?

  private enum Sheet: Identifiable {
    case folders
    case move(MailRow)
    case actions(MailRow)

    var id: String {
      switch self {
      case .folders: "folders"
      case .move(let row): "move-\(row.ref)"
      case .actions(let row): "actions-\(row.ref)"
      }
    }
  }

  var body: some View {
    List {
      if model.state?.keyword == nil { outboxSection }
      if let state = model.state { content(state) }
    }
    .listStyle(.insetGrouped)
    .overlay {
      if model.state?.loading ?? true { ProgressView() }
    }
    .refreshable { await model.reload() }
    // 和搜尋課程一樣一直顯示、釘在導覽列下面，不會捲走；清單捲到後面時由系統淡出。
    .searchable(
      text: $model.searchText, isPresented: $model.searchPresented,
      placement: .navigationBarDrawer(displayMode: .always), prompt: L10n.mailSearchHint)
    .searchScopes($model.scope, activation: .onSearchPresentation) {
      Text(model.state?.folderTitle ?? L10n.mailFolderInbox).tag(MailSearchScope.folder)
      Text(L10n.mailSearchScopeAll).tag(MailSearchScope.all)
    }
    .autocorrectionDisabled()
    .onSubmit(of: .search) { Task { await model.submitSearch() } }
    .onChange(of: model.scope) { Task { await model.scopeChanged() } }
    .onChange(of: model.searchText) { _, text in
      if text.isEmpty { Task { await model.clearSearch() } }
    }
    .onChange(of: model.searchPresented) { _, presented in
      if !presented { Task { await model.endSearch() } }
    }
    .navigationTitle(model.state?.folderTitle ?? L10n.mailTab)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { toolbar }
    .sheet(item: $sheet, onDismiss: runAfterDismiss) { sheetContent($0) }
    .alert(
      L10n.mailDraftDiscard,
      isPresented: Binding(get: { discarding != nil }, set: { if !$0 { discarding = nil } }),
      presenting: discarding
    ) { item in
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.mailDiscard, role: .destructive) { Task { _ = await model.recall(item) } }
    } message: { item in
      Text(item.subject)
    }
  }

  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .topBarTrailing) {
      Button {
        showFolders(.folders)
      } label: {
        LucideImage(Lucide.folder, size: 20)
      }
      .accessibilityLabel(L10n.mailFolders)
      .toolbarButtonTint()

      Button(action: onCompose) {
        LucideImage(Lucide.penLine, size: 20)
      }
      .accessibilityLabel(L10n.mailCompose)
      .toolbarButtonTint()
    }
  }

  @ViewBuilder private func content(_ state: MailListState) -> some View {
    if let notice = state.notice {
      Section {
        NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh, inList: true) {
          Task { await model.reload() }
        }
      }
    }
    if let error = state.error, !state.needsSetup {
      Section {
        InlineErrorView(message: error, signedIn: true, presenter: app.presenter) { await model.reload() }
      }
    }
    if let keyword = state.keyword {
      results(state, keyword: keyword)
    } else {
      // 空信箱也要看得到寄件匣：剛寄出第一封信的人會以為信不見了。
      if let empty = state.emptyMessage, app.mailCenter.outbox.isEmpty {
        Section {
          SectionEmptyState(message: empty, icon: Lucide.mail)
            .listRowBackground(Color.clear)
        }
      }
      ForEach(state.sections, id: \.title) { section in
        Section(section.title) {
          ForEach(section.rows, id: \.ref) { listRow($0) }
        }
      }
      if !state.sections.isEmpty { footer(state) }
    }
  }

  // MARK: - 搜尋

  @ViewBuilder private func results(_ state: MailListState, keyword: String) -> some View {
    if let empty = state.emptyMessage {
      Section {
        SectionEmptyState(message: empty, icon: Lucide.search)
          .listRowBackground(Color.clear)
      }
    } else if !state.results.isEmpty {
      Section {
        ForEach(state.results, id: \.ref) { row in
          Button {
            onOpen(row)
          } label: {
            MailRowView(row: row, highlight: keyword)
          }
          .buttonStyle(.plain)
        }
      } header: {
        if let count = state.resultCount {
          Text(count).monospacedDigit()
        }
      }
    }
    // 找不到的時候使用者分不出是「這個資料夾沒有」還是「整個信箱都沒有」，第二條路留著。
    if !state.searchAll && !state.loading {
      Section {
        Button(L10n.mailSearchAllFolders) { model.scope = .all }
      }
    }
  }

  // MARK: - 列

  private func listRow(_ row: MailRow) -> some View {
    Button {
      onOpen(row)
    } label: {
      MailRowView(row: row)
    }
    .buttonStyle(.plain)
    .swipeActions(edge: .leading) {
      Button {
        Task { await toggleSeen(row) }
      } label: {
        iconLabel(row.unread ? L10n.mailSeenShort : L10n.mailUnseenShort, row.unread ? Lucide.mailOpen : Lucide.mail)
      }
      .tint(Color(.systemBlue))
    }
    // 刪除排在最外側、手指要走最遠；它只是搬到回收筒，救得回來，所以不跳確認。
    .swipeActions(edge: .trailing) {
      Button {
        Task { await trash(row) }
      } label: {
        iconLabel(L10n.delete, Lucide.trash2)
      }
      .tint(Color(.systemRed))
      Button {
        Task { await archive(row) }
      } label: {
        iconLabel(L10n.mailFolderArchive, Lucide.archive)
      }
      .tint(Color.tatBrand)
      Button {
        sheet = .actions(row)
      } label: {
        iconLabel(L10n.titleMore, Lucide.ellipsis)
      }
      .tint(Color(.systemGray))
    }
    .contextMenu {
      Button {
        Task { await toggleSeen(row) }
      } label: {
        iconLabel(row.unread ? L10n.mailMarkRead : L10n.mailMarkUnread, row.unread ? Lucide.mailOpen : Lucide.mail)
      }
      Button {
        showFolders(.move(row))
      } label: {
        iconLabel(L10n.mailMoveToFolder, Lucide.folder)
      }
      Button {
        Task { await archive(row) }
      } label: {
        iconLabel(L10n.mailFolderArchive, Lucide.archive)
      }
      Button(role: .destructive) {
        Task { await trash(row) }
      } label: {
        iconLabel(L10n.delete, Lucide.trash2, destructive: true)
      }
    }
  }

  /// 系統的選單與滑動按鈕只畫得出 `Image`。[destructive] 只給長按選單用：滑動按鈕底色已經是紅的。
  private func iconLabel(_ title: String, _ icon: LucideIcon, destructive: Bool = false) -> some View {
    Label {
      Text(title)
    } icon: {
      Image(uiImage: destructive ? icon.destructiveUIImage() : icon.uiImage())
    }
  }

  /// 清單最底下那一列。捲到這裡就自己載下一頁；失敗過就閂住，換成一顆讓人自己再試的鈕。
  private func footer(_ state: MailListState) -> some View {
    Section {
      Group {
        switch state.more {
        case .more:
          ProgressView()
            .task(id: state.sections.reduce(0) { $0 + $1.rows.count }) { await model.loadMore() }
        case .failed:
          Button(L10n.mailLoadMore) { Task { await model.loadMore() } }
        case .end:
          Text(L10n.mailNoMore)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity)
      .listRowBackground(Color.clear)
    }
  }

  // MARK: - 寄件匣

  /// 只在有東西的時候出現，放在清單最上面：按下寄出之後眼睛還在這一頁，收回鈕要在看得到的地方。
  @ViewBuilder private var outboxSection: some View {
    let outbox = app.mailCenter.outbox
    if !outbox.isEmpty {
      Section(L10n.mailOutbox) {
        ForEach(outbox, id: \.id) { outboxRow($0) }
      }
    }
  }

  /// 三種狀態各只給一個動作：還在等的收回、失敗的重試，寄送中的收不回來所以沒有鈕。
  private func outboxRow(_ item: MailOutboxRow) -> some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          switch item.phase {
          case .waiting: LucideImage(Lucide.clock, size: 14)
          case .sending: ProgressView().controlSize(.mini)
          case .failed: LucideImage(Lucide.triangleAlert, size: 14)
          }
          Text(item.status)
            .font(.footnote.monospacedDigit())
            .lineLimit(1)
        }
        .foregroundStyle(item.phase == .failed ? Color(.systemRed) : Color.tatBrand)
        Text(item.subject)
          .font(.body.weight(.medium))
          .lineLimit(1)
        if !item.recipients.isEmpty {
          Text(item.recipients)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      switch item.phase {
      case .waiting:
        Button(L10n.mailRecall) { Task { await recall(item) } }
          .buttonStyle(.borderless)
      case .failed:
        Button(L10n.mailRetry) { Task { await model.retry(item) } }
          .buttonStyle(.borderless)
      case .sending:
        EmptyView()
      }
    }
    .contextMenu {
      // 失敗的那一封長按才給刪除：那是使用者寫好但沒寄出去的信，誤按就沒了。
      if item.phase == .failed {
        Button(role: .destructive) {
          discarding = item
        } label: {
          iconLabel(L10n.mailDiscard, Lucide.trash2, destructive: true)
        }
      }
    }
  }

  // MARK: - 選單

  @ViewBuilder private func sheetContent(_ sheet: Sheet) -> some View {
    let folders = model.state?.folders ?? []
    let current = model.state?.folderPath ?? ""
    switch sheet {
    case .folders:
      MailFolderSheet(title: L10n.mailFolders, folders: folders, selected: current) { path in
        Task { await model.openFolder(path) }
      }
    case .move(let row):
      MailFolderSheet(title: L10n.mailMoveToFolder, folders: folders, selected: current) { path in
        guard path != current else { return }
        Task { await move(row, to: path) }
      }
    case .actions(let row):
      MailRowActionsSheet(row: row) { action in afterDismiss = { perform(action, on: row) } }
    }
  }

  private func runAfterDismiss() {
    let next = afterDismiss
    afterDismiss = nil
    next?()
  }

  private func perform(_ action: MailRowActionsSheet.Action, on row: MailRow) {
    switch action {
    case .toggleSeen: Task { await toggleSeen(row) }
    case .move: showFolders(.move(row))
    case .archive: Task { await archive(row) }
    case .trash: Task { await trash(row) }
    }
  }

  /// 還沒問到資料夾清單時沒有東西可以選。
  private func showFolders(_ next: Sheet) {
    if model.state?.folders.isEmpty ?? true {
      app.presenter.toast(L10n.mailActionFailed, kind: .error)
    } else {
      sheet = next
    }
  }

  // MARK: - 動作

  private func toggleSeen(_ row: MailRow) async {
    let ok = await model.toggleSeen(row)
    report(ok, done: row.unread ? L10n.mailMarkRead : L10n.mailMarkedUnread)
  }

  private func trash(_ row: MailRow) async {
    report(await model.trash(row), done: L10n.mailMovedToTrash)
  }

  private func archive(_ row: MailRow) async {
    report(await model.archive(row), done: L10n.mailArchived)
  }

  private func move(_ row: MailRow, to path: String) async {
    report(await model.move(row, to: path), done: L10n.mailMoved)
  }

  /// 收不回來只有一種情況：剛好在按下去的那一瞬間交給 SMTP 了，那時說「已收回」是騙人的。
  private func recall(_ item: MailOutboxRow) async {
    let ok = await model.recall(item)
    app.presenter.toast(ok ? L10n.mailRecalled : L10n.mailOutboxSending, kind: ok ? .info : .error)
  }

  private func report(_ ok: Bool, done: String) {
    app.presenter.toast(ok ? done : L10n.mailActionFailed, kind: ok ? .info : .error)
  }
}

/// 信件清單的一列，照 `MailTile`：寄件者在上、主旨在下——校內公告的主旨前八個字幾乎都長一樣，
/// 掃這一頁真正在找的是寄件者。未讀用字重、色階與圓點一起講。
struct MailRowView: View {
  let row: MailRow
  var highlight: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(row.from)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text(row.time)
          .monospacedDigit()
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        if row.unread {
          Circle()
            .fill(Color.tatBrand)
            .frame(width: 7, height: 7)
            .alignmentGuide(.firstTextBaseline) { $0.height / 2 + 5 }
            .accessibilityLabel(L10n.mailUnread)
        }
        Text(subject)
          .font(.body.weight(row.unread ? .semibold : .regular))
          .foregroundStyle(Color.primary)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
      }
    }
    .padding(.vertical, 2)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  /// 搜尋時主旨裡命中的那一段標底色：主旨長的時候才看得出為什麼這一封被列出來。
  private var subject: AttributedString {
    var text = AttributedString(row.subject)
    guard let highlight, !highlight.isEmpty else { return text }
    var start = text.startIndex
    while let range = text[start...].range(of: highlight, options: .caseInsensitive) {
      text[range].backgroundColor = Color.tatBrand.opacity(0.22)
      start = range.upperBound
    }
    return text
  }
}
