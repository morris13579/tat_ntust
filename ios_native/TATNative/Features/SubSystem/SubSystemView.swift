import SwiftUI

/// 資訊系統的六個分類。代號是 NTUST 那一側的不透明代號，名稱只能自己對照，同 `sub_system_category.dart`。
struct SubSystemCategory {
  let id: String
  let icon: LucideIcon
  let name: String
  let description: String

  static var all: [SubSystemCategory] {
    [
      SubSystemCategory(id: "service-1", icon: Lucide.bookOpen, name: L10n.curriculum, description: L10n.curriculumDescription),
      SubSystemCategory(id: "service-2", icon: Lucide.idCard, name: L10n.person_info, description: L10n.personInfoDescription),
      SubSystemCategory(id: "service-3", icon: Lucide.bus, name: L10n.campus_life, description: L10n.campusLifeDescription),
      SubSystemCategory(id: "service-4", icon: Lucide.handCoins, name: L10n.financial_support, description: L10n.financialSupportDescription),
      SubSystemCategory(id: "service-5", icon: Lucide.ticket, name: L10n.activities, description: L10n.activitiesDescription),
      SubSystemCategory(id: "service-6", icon: Lucide.folder, name: L10n.resources, description: L10n.resourcesDescription),
    ]
  }

  /// 對不到代號就回 nil：多出一個沒見過的分類時，底下的服務照樣要畫，只是少一列標題。
  static func name(of id: String) -> String? {
    all.first { $0.id == id }?.name
  }
}

@MainActor
@Observable
final class SubSystemModel {
  private(set) var tree: ServiceTree?
  var keyword = ""
  /// 從分類卡進來時只看那一類。
  let serviceId: String?
  private let client: SubSystemClient

  init(client: SubSystemClient, serviceId: String?) {
    self.client = client
    self.serviceId = serviceId
  }

  func load() async {
    tree = nil
    tree = (try? await client.tree()) ?? ServiceTree(categories: [], error: L10n.somethingError, signedIn: true)
  }

  /// 搜尋不打 API：整棵樹已經在手上，每打一個字重抓只會多一次 SSO 檢查。
  func visible(_ category: ServiceCategory) -> [ServiceLink] {
    category.services.filter { matches($0.name) }
  }

  func matches(_ name: String) -> Bool {
    let key = keyword.trimmingCharacters(in: .whitespaces).lowercased()
    return key.isEmpty || name.lowercased().contains(key)
  }
}

/// 資訊系統，照 `sub_system_page.dart`：可搜尋的分段清單，點一項用 App 內的網頁開。
struct SubSystemView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: SubSystemModel
  @State private var page: WebPage?
  let openClassroom: () -> Void

  private struct Group {
    let id: String
    let title: String?
    let services: [ServiceLink]
    let pinsClassroom: Bool
  }

  init(model: SubSystemModel, openClassroom: @escaping () -> Void) {
    _model = State(initialValue: model)
    self.openClassroom = openClassroom
  }

  var body: some View {
    List {
      if let tree = model.tree {
        if let notice = tree.notice {
          NoticeBar(message: notice, icon: Lucide.history, actionLabel: L10n.refresh, inList: true) {
            Task { await model.load() }
          }
        }
        if let error = tree.error, tree.categories.isEmpty {
          InlineErrorView(message: error, signedIn: tree.signedIn, presenter: app.presenter) {
            await model.load()
          }
          .listRowBackground(Color.clear)
        } else {
          let groups = groups(tree)
          ForEach(groups, id: \.id) { group in
            Section {
              if group.pinsClassroom { classroomRow }
              ForEach(Array(group.services.enumerated()), id: \.offset) { _, service in
                Button {
                  open(service)
                } label: {
                  Text(service.name).foregroundStyle(Color.primary)
                }
              }
            } header: {
              if let title = group.title {
                HStack {
                  Text(title)
                  Spacer()
                  Text(L10n.itemCount(String(group.services.count))).monospacedDigit()
                }
              }
            }
          }
          // 關鍵字是空的時候不說「找不到」：那代表學校端回了一份空清單，不是使用者搜尋的錯。
          if groups.isEmpty, !model.keyword.trimmingCharacters(in: .whitespaces).isEmpty {
            SectionEmptyState(message: L10n.subSystemSearchEmpty, icon: Lucide.searchX)
              .listRowBackground(Color.clear)
          }
        }
      }
    }
    // 載入中清單是空的，空清單的底是白的；自己墊清單的灰，載完才不會閃一下。
    .scrollContentBackground(.hidden)
    .background(Color(.systemGroupedBackground))
    .contentMargins(.top, 8, for: .scrollContent)
    .overlay {
      if model.tree == nil { ProgressView() }
    }
    // 推進來的頁面用導覽列的搜尋列，背景要等推頁動畫結束才出現；釘在內容頂端就跟著頁面一起出來。
    // 不墊底色：清單捲到搜尋列後面時由系統淡出，和搜尋課程一樣。
    .pinnedTopBar {
      SystemSearchBar(text: $model.keyword, prompt: L10n.searchService)
        .padding(.horizontal, 8)
    }
    .navigationTitle(model.serviceId.flatMap(SubSystemCategory.name(of:)) ?? L10n.informationSystem)
    .analyticsScreen("/SubSystemPage")
    .navigationBarTitleDisplayMode(.inline)
    .browserSheet(item: $page) { _ in false }
    .task {
      if model.tree == nil { await model.load() }
    }
  }

  private func groups(_ tree: ServiceTree) -> [Group] {
    tree.categories.compactMap { category in
      if let only = model.serviceId, category.serviceId != only { return nil }
      let services = model.visible(category)
      // 空教室釘在「校園資訊」最上面，照 Flutter 版；釘住的這一列也吃搜尋。
      let pinned = category.pinsClassroom && model.matches(L10n.classroomTitle)
      guard !services.isEmpty || pinned else { return nil }
      // 只看單一分類時標題已經是分類名，不再重複畫一次分段標題。
      let title = model.serviceId == nil ? SubSystemCategory.name(of: category.serviceId) : nil
      return Group(id: category.serviceId, title: title, services: services, pinsClassroom: pinned)
    }
  }

  /// App 自己的頁面，所以掛一個「App 內」的籤，點了不開瀏覽器。
  private var classroomRow: some View {
    Button(action: openClassroom) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(L10n.classroomTitle).foregroundStyle(Color.primary)
          Text(L10n.classroomSubSystemHint)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        Text(L10n.classroomInApp)
          .font(.caption.weight(.medium))
          .foregroundStyle(Color.tatBrand)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Color.tatBrand.opacity(0.14), in: Capsule())
      }
    }
  }

  private func open(_ service: ServiceLink) {
    guard let url = URL(string: service.url), url.scheme?.hasPrefix("http") == true else { return }
    page = WebPage(title: service.name, url: url)
  }
}
