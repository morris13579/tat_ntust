import SwiftUI

/// 通知中心，照 `announcement_center_page.dart`：最上面是最新的一則 TAT 公告，底下是 Moodle 站內通知，
/// 依今天、本週、更早分組。有自家網址的點了開網頁，沒有的就地展開內文。
struct InboxView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: InboxModel
  @State private var confirmMarkAll = false
  @State private var showNotices = false

  init(model: InboxModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    let web = Binding(get: { model.web }, set: { model.web = $0 })
    List {
      if let state = model.state {
        content(state)
      }
    }
    .listStyle(.insetGrouped)
    .overlay {
      if let state = model.state {
        // 放在清單外面才會在畫面正中間，而不是清單的第一列。
        if let message = state.emptyMessage { empty(message, hint: state.emptyHint) }
      } else {
        ProgressView()
      }
    }
    .refreshable { await model.refresh() }
    .navigationTitle(L10n.notificationCenterTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) { markAllButton }
    }
    .alert(L10n.notificationMarkAllRead, isPresented: $confirmMarkAll) {
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.sure, role: .destructive) { Task { await model.markAllRead(presenter: app.presenter) } }
    } message: {
      Text(L10n.notificationMarkAllReadConfirm)
    }
    .moodleLinks(client: app.courseMoodle, folder: L10n.notificationCenterTitle, web: web)
    .navigationDestination(isPresented: $showNotices) {
      if let notices = model.state?.notices {
        AnnouncementView(notices: notices, countDown: 0)
      }
    }
    .browserSheet(item: web) { await app.calendar.isAutologinScript($0) }
    .task {
      if model.state == nil { await model.load() }
    }
    .analyticsScreen(model.preview == nil ? "/AnnouncementCenterPage" : "/AnnouncementCenterPreviewPage")
  }

  @ViewBuilder private func content(_ state: InboxState) -> some View {
    if let first = state.notices.first {
      Section { banner(first, unread: state.noticeUnread) }
    }
    if let notice = state.notice {
      Section {
        NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh, inList: true) {
          Task { await model.refresh() }
        }
      }
    }
    if let error = state.error, state.sections.isEmpty {
      Section {
        InlineErrorView(message: error, signedIn: state.signedIn, presenter: app.presenter) {
          await model.retry()
        }
      }
    }
    ForEach(state.sections, id: \.title) { section in
      Section(section.title) {
        ForEach(section.rows, id: \.id) { row($0) }
      }
    }
  }

  /// 它是一整塊、不是清單的一列：底下是別人送來的一長串，這一則是 TAT 自己要說的一件事。
  private func banner(_ notice: InboxNotice, unread: Bool) -> some View {
    Button {
      showNotices = true
    } label: {
      VStack(alignment: .leading, spacing: 9) {
        HStack(spacing: 11) {
          LucideImage(Lucide.megaphone, size: 18)
          Text(L10n.appAnnouncement)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
          if unread {
            Circle().fill(Color.tatBrand).frame(width: 8, height: 8)
              .accessibilityLabel(L10n.notificationUnread)
          }
          Text(notice.date)
            .font(.footnote.monospacedDigit())
            .accessibilityLabel("\(L10n.announcementPublishedAt) \(notice.date)")
        }
        .foregroundStyle(Color.tatBrand)
        Text(notice.title)
          .font(.headline)
          .foregroundStyle(Color.primary)
        if !notice.excerpt.isEmpty {
          Text(notice.excerpt)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(3)
        }
        Text(L10n.announcementReadFull)
          .font(.subheadline.weight(.medium))
          .underline()
          .foregroundStyle(Color.tatBrand)
      }
      .padding(.vertical, 4)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .listRowBackground(Color.tatBrand.opacity(0.12))
  }

  /// 第二行才是重點：「這頁平常本來就很空」得說出來，否則使用者會以為是載入失敗。
  private func empty(_ message: String, hint: String?) -> some View {
    VStack(spacing: 10) {
      LucideImage(Lucide.inbox, size: 40)
        .foregroundStyle(.secondary)
      Text(message).font(.headline)
      if let hint {
        Text(hint)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 32)
    .allowsHitTesting(false)
  }

  private func row(_ row: InboxRow) -> some View {
    let expanded = model.expanded.contains(row.id)
    return Button {
      Task { await model.tap(row) }
    } label: {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 13) {
          LucideImage(Self.icon(row.kind), size: 20)
            .foregroundStyle(Color.tatBrand)
          VStack(alignment: .leading, spacing: 4) {
            // 未讀只差一個字重，是設計稿自己的訊號；圓點是第二個，因為單靠字重在小字上幾乎看不出來。
            Text(row.subject)
              .font(.body.weight(row.unread ? .medium : .regular))
              .foregroundStyle(Color.primary)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
            // 來源與時間分開排：活動名稱沒有長度上限，擠在同一串裡被截掉的會是時間。
            HStack(spacing: 0) {
              Text(row.source).lineLimit(1)
              Text(verbatim: " · \(row.time)").monospacedDigit().layoutPriority(1)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
          }
          Spacer(minLength: 8)
          if row.unread {
            Circle().fill(Color.tatBrand).frame(width: 8, height: 8)
              .accessibilityLabel(L10n.notificationUnread)
          }
          LucideImage(
            row.openable ? Lucide.chevronRight : (expanded ? Lucide.chevronUp : Lucide.chevronDown), size: 16
          )
          .foregroundStyle(.secondary)
        }
        if expanded {
          MoodleHTMLView(html: row.bodyHtml, client: app.courseMoodle)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  /// 伺服器的 `iconurl` 刻意不用：那是站台主題圖，深色模式也不會反相。
  private static func icon(_ kind: InboxKind) -> LucideIcon {
    switch kind {
    case .grade: Lucide.graduationCap
    case .assign: Lucide.clipboardList
    case .forum: Lucide.messagesSquare
    case .quiz: Lucide.fileQuestion
    case .feedback: Lucide.vote
    case .lesson: Lucide.bookOpen
    case .module: Lucide.puzzle
    case .system: Lucide.bell
    }
  }

  @ViewBuilder private var markAllButton: some View {
    if model.markingAll {
      ProgressView()
    } else if model.state?.canMarkAll == true {
      Button {
        confirmMarkAll = true
      } label: {
        LucideImage(Lucide.checkCheck, size: 20)
      }
      .accessibilityLabel(L10n.notificationMarkAllRead)
      .toolbarButtonTint()
    }
  }
}
