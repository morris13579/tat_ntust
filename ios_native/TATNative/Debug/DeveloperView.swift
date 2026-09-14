import StoreKit
import SwiftUI
import UIKit

/// 開發人員選項，照 `dev_page.dart`。只在 Debug 建置出現；項目名稱照 Flutter 版刻意不進翻譯檔。
struct DeveloperView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var announcement: LaunchAnnouncement?

  var body: some View {
    List {
      Section {
        action(Lucide.keyRound, "Cloud Messaging Token") { Task { await copyToken() } }
        NavigationLink { HttpLogView(client: app.developer) } label: { label(Lucide.info, "Dio Log") }
        NavigationLink { LogConsoleView(client: app.developer) } label: { label(Lucide.info, "App Log") }
        NavigationLink { StoreEditView(client: app.developer) } label: { label(Lucide.pencil, "Store Edit") }
        action(Lucide.megaphone, "Announcement") { Task { await showAnnouncement() } }
        NavigationLink { InboxPreviewList(client: app.inbox) } label: { label(Lucide.bell, "Notification Preview") }
        action(Lucide.shieldCheck, "Store Review") { requestReview() }
      }
      Section {
        NavigationLink {
          ProbeView(model: ProbeModel(core: app.core))
        } label: {
          label(Lucide.codeXml, "Core Probe")
        }
      }
    }
    .navigationTitle(L10n.developerMode)
    .navigationBarTitleDisplayMode(.inline)
    // 照 DevPage.initState：Remote Config 不快取，剛改的公告馬上看得到。
    .task { try? await app.appNotice.refreshRemoteConfig() }
    .sheet(isPresented: Binding(get: { announcement != nil }, set: { if !$0 { announcement = nil } })) {
      if let launch = announcement {
        NavigationStack {
          AnnouncementView(notices: launch.notices, countDown: Int(launch.countDown), showClose: true)
        }
      }
    }
    .analyticsScreen("/DevPage")
  }

  private func label(_ icon: LucideIcon, _ title: String) -> some View {
    HStack(spacing: 12) {
      LucideImage(icon, size: 20)
        .foregroundStyle(.secondary)
        .frame(width: 28)
      Text(verbatim: title).foregroundStyle(Color.primary)
    }
  }

  private func action(_ icon: LucideIcon, _ title: String, perform: @escaping () -> Void) -> some View {
    Button(action: perform) { label(icon, title) }
  }

  private func copyToken() async {
    guard let token = await app.push.token() else {
      app.presenter.toast("Cloud Messaging Token 取不到", kind: .error)
      return
    }
    UIPasteboard.general.string = token
    app.presenter.toast("\(token) copy")
  }

  private func showAnnouncement() async {
    announcement = try? await app.appNotice.launchAnnouncement(test: true)
    if announcement == nil { app.presenter.toast("沒有公告") }
  }

  /// 直接叫系統的評分視窗，跳過那三道門檻。系統自己也會擋（debug build 多半什麼都不會出現），叫不出來是正常的。
  private func requestReview() {
    guard
      let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive })
        as? UIWindowScene
    else {
      app.presenter.toast("in_app_review 不可用")
      return
    }
    AppStore.requestReview(in: scene)
  }
}

/// 通知頁的假資料預覽，照 `announcement_center_preview_page.dart`：一個帳號同一時間只看得到其中一種樣子。
struct InboxPreviewList: View {
  let client: InboxClient
  @State private var items: [InboxPreviewItem] = []

  var body: some View {
    List(Array(items.enumerated()), id: \.offset) { index, item in
      NavigationLink {
        InboxView(model: InboxModel(client: client, preview: index))
      } label: {
        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: item.title)
          Text(verbatim: item.subtitle).font(.footnote).foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle(Text(verbatim: "Notification Preview"))
    .navigationBarTitleDisplayMode(.inline)
    .task { items = (try? await client.previewItems()) ?? [] }
  }
}

/// App 的記錄，照 Flutter 版的 `LogConsole`：核心的環形緩衝，新的在上面。
struct LogConsoleView: View {
  let client: DeveloperClient
  @State private var entries: [LogEntry] = []

  var body: some View {
    List(Array(entries.enumerated()), id: \.offset) { _, entry in
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: entry.level.uppercased())
          .font(.caption2.weight(.bold))
          .foregroundStyle(color(entry.level))
        Text(verbatim: entry.text)
          .font(.caption.monospaced())
          .textSelection(.enabled)
      }
    }
    .listStyle(.plain)
    .navigationTitle(Text(verbatim: "App Log"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        ShareLink(item: entries.map(\.text).joined(separator: "\n\n")) {
          LucideImage(Lucide.share2, size: 20)
        }
        .toolbarButtonTint()
        Button {
          Task {
            try? await client.clearLogs()
            await load()
          }
        } label: {
          LucideImage(Lucide.trash2, size: 20)
        }
        .toolbarButtonTint()
      }
    }
    .refreshable { await load() }
    .task { await load() }
    .analyticsScreen("/LogConsole")
  }

  private func load() async {
    entries = (try? await client.logs()) ?? []
  }

  private func color(_ level: String) -> Color {
    switch level {
    case "error", "fatal": Color(.systemRed)
    case "warning": Color(.systemOrange)
    default: .secondary
    }
  }
}

/// 最近的 HTTP 請求，取代 Flutter 版的 alice 介面。秘密在核心那一側就遮掉了。
struct HttpLogView: View {
  let client: DeveloperClient
  @State private var calls: [HttpCallEntry] = []

  var body: some View {
    List(calls, id: \.id) { call in
      NavigationLink {
        HttpCallDetailView(call: call)
      } label: {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(verbatim: call.method).font(.caption.weight(.bold))
            Text(verbatim: call.status.map { "\($0)" } ?? (call.error == nil ? "…" : "ERR"))
              .font(.caption.monospacedDigit())
              .foregroundStyle(call.error != nil || (call.status ?? 0) >= 400 ? Color(.systemRed) : .secondary)
            Spacer()
            if call.durationMs >= 0 {
              Text(verbatim: "\(call.durationMs) ms").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
          }
          Text(verbatim: call.url).font(.caption.monospaced()).lineLimit(2)
        }
      }
    }
    .listStyle(.plain)
    .overlay {
      if calls.isEmpty { Text(verbatim: "只有 Debug 建置會記錄").foregroundStyle(.secondary) }
    }
    .navigationTitle(Text(verbatim: "Dio Log"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Task {
            try? await client.clearHttpCalls()
            await load()
          }
        } label: {
          LucideImage(Lucide.trash2, size: 20)
        }
        .toolbarButtonTint()
      }
    }
    .refreshable { await load() }
    .task { await load() }
  }

  private func load() async {
    calls = (try? await client.httpCalls()) ?? []
  }
}

struct HttpCallDetailView: View {
  let call: HttpCallEntry

  var body: some View {
    List {
      Section { mono("\(call.method) \(call.url)") }
      if let error = call.error {
        Section { mono(error) } header: { Text(verbatim: "Error") }
      }
      Section { mono(call.requestHeaders) } header: { Text(verbatim: "Request headers") }
      if let text = call.requestBody {
        Section { mono(text) } header: { Text(verbatim: "Request body") }
      }
      Section { mono(call.responseHeaders) } header: { Text(verbatim: "Response headers") }
      if let text = call.responseBody {
        Section { mono(text) } header: { Text(verbatim: "Response body") }
      }
    }
    .navigationTitle(Text(verbatim: call.status.map { "\($0)" } ?? call.method))
    .navigationBarTitleDisplayMode(.inline)
  }

  private func mono(_ text: String) -> some View {
    Text(verbatim: text).font(.caption.monospaced()).textSelection(.enabled)
  }
}

extension StoreEntry: Identifiable {
  var id: String { key }
}

/// 直接改 SharedPreferences，照 `store_edit_page.dart`：憑證不回顯、只有字串與整數改得了，離開時重讀設定。
struct StoreEditView: View {
  let client: DeveloperClient
  @State private var entries: [StoreEntry] = []
  @State private var editing: StoreEntry?
  @State private var draft = ""

  var body: some View {
    List {
      ForEach(entries) { entry in
        Button {
          guard entry.editable else { return }
          draft = entry.value
          editing = entry
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: entry.key).foregroundStyle(Color.primary)
            if !entry.sensitive, !entry.value.isEmpty {
              Text(verbatim: entry.value)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
          }
        }
        .swipeActions {
          Button(role: .destructive) {
            Task {
              try? await client.removeStoreKey(entry.key)
              await load()
            }
          } label: {
            Label { Text(verbatim: "Delete") } icon: { Image(uiImage: Lucide.trash2.uiImage()) }
          }
        }
      }
    }
    .navigationTitle(Text(verbatim: "Edit Page"))
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $editing) { entry in editor(entry) }
    .task { await load() }
    .onDisappear { Task { try? await client.reloadStore() } }
    .analyticsScreen("/StoreEditPage")
  }

  private func editor(_ entry: StoreEntry) -> some View {
    NavigationStack {
      TextEditor(text: $draft)
        .font(.caption.monospaced())
        .padding(8)
        .navigationTitle(Text(verbatim: entry.key))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(L10n.cancel) { editing = nil }
              .toolbarButtonTint()
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(L10n.sure) {
              let value = draft
              editing = nil
              Task {
                try? await client.setStoreValue(key: entry.key, value: value)
                await load()
              }
            }
          }
        }
    }
  }

  private func load() async {
    entries = (try? await client.storeEntries()) ?? []
  }
}
