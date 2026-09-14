import SwiftUI

/// 「更多」，照 `other_page.dart`：帳號、空教室、資訊系統的分類、設定、關於 TAT、登入或登出。
struct MoreView: View {
  @Environment(AppEnvironment.self) private var app
  @State private var model: MoreModel
  @State private var path: [Route] = []
  @State private var web: WebPage?
  @State private var confirmLogout = false
  @State private var updateOffer: UpdateOffer?
  @State private var choosingColor = false

  enum Route: Hashable {
    case profile, classroom, moodleSetting, about
    case subSystem(String?)
  }

  init(model: MoreModel) {
    _model = State(initialValue: model)
  }

  var body: some View {
    NavigationStack(path: $path) {
      List {
        Section { account }

        // 空教室自己一組、在資訊系統上面：它是 App 自己的頁面，混進校務網站的分類會讓人以為又要開瀏覽器。
        Section {
          row(Lucide.doorOpen, L10n.classroomTitle, subtitle: L10n.classroomEntryDescription) {
            path.append(.classroom)
          }
        }

        Section {
          categories
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
          HStack {
            Text(L10n.informationSystem)
            Spacer()
            Button(L10n.allServices) { path.append(.subSystem(nil)) }
              .font(.subheadline.weight(.medium))
          }
          .textCase(nil)
        }

        Section(L10n.setting) {
          row(Lucide.graduationCap, L10n.moodle_setting, subtitle: L10n.moodle_setting_description) {
            path.append(.moodleSetting)
          }
          // 只有兩個語言、沒有「跟隨系統」，同 Flutter 版的 `showLanguageSheet`。
          Picker(selection: Binding(get: { app.language ?? .zhTW }, set: { choose($0) })) {
            Text(L10n.languageZhTW).tag(AppLanguage.zhTW)
            Text(L10n.languageEn).tag(AppLanguage.en)
          } label: {
            iconLabel(Lucide.languages, L10n.languageSetting)
          }
          .pickerStyle(.menu)
          Picker(selection: Binding(get: { model.theme }, set: { theme in
            app.applyTheme(theme)
            Task { await model.setTheme(theme) }
          })) {
            ForEach(ThemeChoice.allCases, id: \.self) { theme in
              Text(themeName(theme)).tag(theme)
            }
          } label: {
            iconLabel(Lucide.palette, L10n.theme_setting)
          }
          .pickerStyle(.menu)
          Button {
            choosingColor = true
          } label: {
            HStack(spacing: 12) {
              iconLabel(Lucide.swatchBook, L10n.themeColor)
              Spacer(minLength: 8)
              Circle()
                .fill(Color.tatBrand)
                .frame(width: 20, height: 20)
              LucideImage(Lucide.chevronRight, size: 16)
                .foregroundStyle(Color(.secondaryLabel))
            }
            .contentShape(Rectangle())
          }
          .foregroundStyle(Color.primary)
        }

        Section(L10n.groupAboutTat) {
          row(Lucide.messageSquare, L10n.feedback) { Task { await openFeedback() } }
          row(Lucide.cloudDownload, L10n.checkVersion, value: appVersion) { Task { await checkVersion() } }
          row(Lucide.info, L10n.about) { path.append(.about) }
        }

        // 整頁唯一會改變登入狀態的動作，不跟「關於 TAT」混在一組。
        Section { accountButton }
      }
      .listStyle(.insetGrouped)
      // 第一段沒有標題時系統會空出一段標題的高度，接在導覽列下面顯得太空。
      .contentMargins(.top, 16, for: .scrollContent)
      .navigationTitle(L10n.titleMore)
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(for: Route.self) { destination($0) }
      .browserSheet(item: $web) { _ in false }
      .sheet(isPresented: $choosingColor) { ThemeColorSheet(model: model) }
    }
    .updateAlert($updateOffer) { Task { try? await app.appNotice.ignoreUpdate() } }
    .alert(L10n.logoutConfirmTitle, isPresented: $confirmLogout) {
      Button(L10n.cancel, role: .cancel) {}
      Button(L10n.sure, role: .destructive) { Task { await app.signOut() } }
    } message: {
      Text(L10n.logoutConfirmDesc)
    }
    .task { await model.start() }
  }

  @ViewBuilder private var account: some View {
    switch model.profile {
    case .signedOut:
      Text(L10n.pleaseLogin)
        .padding(.vertical, 6)
    case .loading:
      HStack(spacing: 12) {
        Circle().fill(Color(.systemFill)).frame(width: 48, height: 48)
        VStack(alignment: .leading, spacing: 8) {
          Capsule().fill(Color(.systemFill)).frame(width: 110, height: 12)
          Capsule().fill(Color(.systemFill)).frame(width: 80, height: 10)
        }
      }
      .padding(.vertical, 4)
      .accessibilityHidden(true)
    case .failed:
      // 載入結束但沒有資料：Moodle token 過期、斷網。要有重試入口，不能停在載入的樣子。
      Button {
        Task { await model.loadProfile(interactive: true) }
      } label: {
        HStack {
          Text(L10n.somethingError).foregroundStyle(Color(.secondaryLabel))
          Spacer()
          LucideImage(Lucide.refreshCw, size: 20).foregroundStyle(Color(.secondaryLabel))
        }
      }
    case .loaded(let profile):
      NavigationLink(value: Route.profile) {
        HStack(spacing: 12) {
          AvatarView(url: profile.avatarUrl, size: 48)
          VStack(alignment: .leading, spacing: 4) {
            Text(profile.name).font(.headline)
            Text(profile.account)
              .font(.subheadline.monospacedDigit())
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 4)
      }
    }
  }

  /// 分類攤成兩欄，第一眼就看得到裡面有什麼；真正的清單進資訊系統頁才抓。
  private var categories: some View {
    LazyVGrid(
      columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10
    ) {
      ForEach(SubSystemCategory.all, id: \.id) { category in
        Button {
          path.append(.subSystem(category.id))
        } label: {
          VStack(alignment: .leading, spacing: 6) {
            LucideImage(category.icon, size: 20).foregroundStyle(Color.tatBrand)
            Text(category.name)
              .font(.headline)
              .foregroundStyle(Color.primary)
            Text(category.description)
              .font(.footnote)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.leading)
          }
          .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
          .padding(14)
          .background(
            Color(.secondarySystemGroupedBackground),
            in: ListGroupShape.card)
        }
        .buttonStyle(.plain)
      }
    }
  }

  @ViewBuilder private var accountButton: some View {
    if model.signedIn {
      Button(role: .destructive) {
        confirmLogout = true
      } label: {
        Label { Text(L10n.logout) } icon: { LucideImage(Lucide.logOut, size: 18).foregroundStyle(Color(.systemRed)) }
          .frame(maxWidth: .infinity)
      }
    } else {
      Button {
        app.presenter.requestLogin { Task { await model.loadProfile(interactive: false) } }
      } label: {
        Label { Text(L10n.login) } icon: { LucideImage(Lucide.logIn, size: 18) }
          .frame(maxWidth: .infinity)
      }
    }
  }

  private func row(
    _ icon: LucideIcon, _ title: String, subtitle: String? = nil, value: String? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        LucideImage(icon, size: 20)
          .foregroundStyle(Color.tatBrand)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 2) {
          Text(title).foregroundStyle(Color.primary)
          if let subtitle {
            Text(subtitle).font(.subheadline).foregroundStyle(Color(.secondaryLabel))
          }
        }
        Spacer(minLength: 8)
        // 目前的值直接寫在右邊，不必點進去才知道。
        if let value {
          Text(value).foregroundStyle(Color(.secondaryLabel))
        }
        LucideImage(Lucide.chevronRight, size: 16)
          .foregroundStyle(Color(.secondaryLabel))
      }
      .contentShape(Rectangle())
    }
  }

  private func iconLabel(_ icon: LucideIcon, _ title: String) -> some View {
    HStack(spacing: 12) {
      LucideImage(icon, size: 20)
        .foregroundStyle(Color.tatBrand)
        .frame(width: 28)
      Text(title)
    }
  }

  @ViewBuilder private func destination(_ route: Route) -> some View {
    switch route {
    case .profile:
      ProfileView(model: model) { path.append(.subSystem(nil)) }
    case .classroom:
      ClassroomView(model: ClassroomModel(client: app.classroom))
    case .moodleSetting:
      MoodleSettingView(model: MoodleSettingModel(client: app.moodleSetting))
    case .about:
      AboutView()
    case .subSystem(let serviceId):
      SubSystemView(model: SubSystemModel(client: app.subSystem, serviceId: serviceId)) {
        path.append(.classroom)
      }
    }
  }

  private func choose(_ language: AppLanguage) {
    guard language != app.language else { return }
    Task {
      try? await app.core.setLanguage(language)
      app.apply(language)
    }
  }

  private func openFeedback() async {
    guard let link = try? await model.client.feedbackUrl(), let url = URL(string: link) else { return }
    web = WebPage(title: L10n.feedback, url: url)
  }

  /// 使用者自己來問：略過過的版本也照樣跳，跟啟動時同一個提示。
  private func checkVersion() async {
    app.presenter.toast(L10n.checkingVersion)
    if let offer = try? await app.appNotice.updateOffer(manual: true) {
      updateOffer = offer
    } else {
      app.presenter.toast(L10n.isNewVersion)
    }
  }

  private func themeName(_ theme: ThemeChoice) -> String {
    switch theme {
    case .system: L10n.theme_system
    case .light: L10n.theme_light
    case .dark: L10n.theme_dark
    }
  }

  private var appVersion: String? {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
  }
}

/// 頭貼。載不出來或沒有自訂時是一個人像圖示。
struct AvatarView: View {
  let url: String?
  let size: CGFloat

  var body: some View {
    AsyncImage(url: url.flatMap(URL.init(string:))) { phase in
      if let image = phase.image {
        image.resizable().scaledToFill()
      } else {
        LucideImage(Lucide.user, size: size * 0.46)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(.systemFill))
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
  }
}
