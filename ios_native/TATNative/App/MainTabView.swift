import SwiftUI

/// 五個分頁。**順序與 Flutter 的 `MainTab` 一致**：分析事件靠索引對應。
struct MainTabView: View {
  @Environment(AppEnvironment.self) private var app
  @Environment(\.scenePhase) private var scenePhase
  @State private var tab: Tab = .courseTable
  /// 新信橫幅點下去要打開的那一封，信箱分頁接手之後清掉。
  @State private var openMail: MailArrival?
  @State private var windowBottom: CGFloat = 0
  @State private var contentBottom: CGFloat = 0

  enum Tab: Hashable { case courseTable, mail, calendar, score, more }

  /// 跟分頁同一個順序：`TabBarSelectedImages` 照順序對到分頁列的每一格。
  private static let icons = [Lucide.table, Lucide.mail, Lucide.calendarDays, Lucide.graduationCap, Lucide.menu]

  var body: some View {
    TabView(selection: $tab) {
      CourseTableView(
        model: CourseTableModel(client: app.courseTable, inbox: app.inbox, simulation: app.simulation))
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { contentBottom = $0 }
        .background(TabBarSelectedImages(images: Self.icons.map { $0.filledUIImage() }))
        .tabItem { label(L10n.titleCourse, Lucide.table) }
        .tag(Tab.courseTable)

      MailView(model: MailListModel(client: app.mail, center: app.mailCenter), openMail: $openMail)
        .tabItem { label(L10n.mailTab, Lucide.mail) }
        .tag(Tab.mail)

      CalendarView(model: CalendarModel(client: app.calendar))
        .tabItem { label(L10n.calendar, Lucide.calendarDays) }
        .tag(Tab.calendar)

      ScoreView(model: ScoreModel(client: app.score))
        .tabItem { label(L10n.titleScore, Lucide.graduationCap) }
        .tag(Tab.score)

      MoreView(model: MoreModel(client: app.more))
        .tabItem { label(L10n.titleMore, Lucide.menu) }
        .tag(Tab.more)
    }
    .onChange(of: tab) { _, tab in AppAnalytics.screen(tab.analyticsName) }
    // 分頁內容的安全區域比整個 TabView 多出來的那一段就是分頁列，提示要浮在它上面。
    .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { windowBottom = $0 }
    .onChange(of: contentBottom - windowBottom, initial: true) { _, inset in app.presenter.bottomBarInset = max(0, inset) }
    .onDisappear { app.presenter.bottomBarInset = 0 }
    .analyticsScreen("/home")
    .modifier(LaunchNotices())
    .task {
      try? await app.mail.restoreOutbox()
      try? await app.mail.startWatch()
    }
    // 信箱只在前景盯：這一版刻意不做背景輪詢，照 `MainScreen.didChangeAppLifecycleState`。
    .onChange(of: scenePhase) { _, phase in
      switch phase {
      case .active:
        Task { try? await app.mail.startWatch() }
      case .background:
        Task { try? await app.mail.stopWatch() }
        app.presenter.dismissBanner()
      default:
        break
      }
    }
    .onChange(of: app.mailCenter.arrivals) { showArrival() }
    // 寄件匣的回報接在這裡而不是信件清單：寄完信常常就切去別的分頁了。
    .onChange(of: app.mailCenter.sentCount) {
      let sent = app.mailCenter.lastSent
      app.presenter.toast(sent ? L10n.mailSent : L10n.mailSendFailed, kind: sent ? .success : .error)
    }
  }

  /// 新信到了：畫一條點得下去的橫幅，照 `MainScreen._onNewMail`。
  private func showArrival() {
    guard let arrival = app.mailCenter.arrival else { return }
    app.presenter.showBanner(icon: Lucide.mail, title: arrival.title, message: arrival.message) {
      tab = .mail
      openMail = arrival
    }
  }

  /// 選到時的實心版不在這裡換，交給 `TabBarSelectedImages`。
  private func label(_ title: String, _ icon: LucideIcon) -> some View {
    Label {
      Text(title)
    } icon: {
      Image(uiImage: icon.uiImage())
    }
  }
}

extension MainTabView.Tab {
  /// Flutter 版 `MainTab` 的名字：送出去的是名字不是索引，改名等於改掉既有的報表維度。
  var analyticsName: String {
    switch self {
    case .courseTable: "courseTable"
    case .mail: "mail"
    case .calendar: "calendar"
    case .score: "score"
    case .more: "other"
    }
  }
}

/// SwiftUI 的分頁沒有「選到時的圖」可以設；選到才換圖的話，Liquid Glass 拖曳經過的那一格還是線條版。
/// 直接把實心圖設成 `UITabBarItem.selectedImage`，什麼時候用哪一張交給系統。
private struct TabBarSelectedImages: UIViewControllerRepresentable {
  let images: [UIImage]

  func makeUIViewController(context: Context) -> Controller { Controller() }

  func updateUIViewController(_ controller: Controller, context: Context) {
    controller.images = images
    controller.apply()
  }

  final class Controller: UIViewController {
    var images: [UIImage] = []

    override func didMove(toParent parent: UIViewController?) {
      super.didMove(toParent: parent)
      apply()
    }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      apply()
    }

    func apply() {
      var node: UIViewController? = parent
      while let current = node, !(current is UITabBarController) { node = current.parent }
      guard let items = (node as? UITabBarController)?.tabBar.items else { return }
      for (item, image) in zip(items, images) where item.selectedImage !== image {
        item.selectedImage = image
      }
    }
  }
}
