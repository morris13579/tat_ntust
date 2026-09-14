import Observation
import SwiftUI

/// 唯一的依賴容器，畫面從 SwiftUI environment 取得，再用它建自己的 Model。
@MainActor
@Observable
final class AppEnvironment {
  let presenter = UiPresenter()
  let transfers = TransferCenter()
  let push = PushNotifications()
  let mailCenter = MailCenter()
  let core: CoreClient
  let courseTable: CourseTableClient
  let courseDetail: CourseDetailClient
  let courseMoodle: CourseMoodleClient
  let assignment: AssignmentClient
  let quiz: QuizClient
  let forum: ForumClient
  let courseSearch: CourseSearchClient
  let score: ScoreClient
  let calendar: CalendarClient
  let more: MoreClient
  let subSystem: SubSystemClient
  let moodleSetting: MoodleSettingClient
  let classroom: ClassroomClient
  let inbox: InboxClient
  let appNotice: AppNoticeClient
  let browser: BrowserClient
  let simulation: SimulationClient
  let developer: DeveloperClient
  let mail: MailClient
  let widgets: WidgetSync
  private let engine = CoreEngine()
  private let uiHost: CoreUiHost

  /// nil 代表核心還沒回答。
  private(set) var language: AppLanguage?

  /// nil 代表跟系統。
  private(set) var colorScheme: ColorScheme?

  /// 每登出一次加一，`RootView` 看到就回登入頁。
  private(set) var signOutCount = 0

  /// 上一次核心的回答，啟動時先照它畫。
  private(set) var launchHint: LaunchHint?
  private var theme: ThemeChoice?

  init() {
    core = CoreClient(messenger: engine.messenger)
    courseTable = CourseTableClient(messenger: engine.messenger)
    courseDetail = CourseDetailClient(messenger: engine.messenger)
    courseMoodle = CourseMoodleClient(messenger: engine.messenger)
    assignment = AssignmentClient(messenger: engine.messenger)
    quiz = QuizClient(messenger: engine.messenger)
    forum = ForumClient(messenger: engine.messenger)
    courseSearch = CourseSearchClient(messenger: engine.messenger)
    score = ScoreClient(messenger: engine.messenger)
    calendar = CalendarClient(messenger: engine.messenger)
    more = MoreClient(messenger: engine.messenger)
    subSystem = SubSystemClient(messenger: engine.messenger)
    moodleSetting = MoodleSettingClient(messenger: engine.messenger)
    classroom = ClassroomClient(messenger: engine.messenger)
    inbox = InboxClient(messenger: engine.messenger)
    appNotice = AppNoticeClient(messenger: engine.messenger)
    simulation = SimulationClient(messenger: engine.messenger)
    developer = DeveloperClient(messenger: engine.messenger)
    mail = MailClient(messenger: engine.messenger)
    widgets = WidgetSync(client: WidgetClient(messenger: engine.messenger))
    let webSessions = CoreWebSessions(messenger: engine.messenger, presenter: presenter)
    browser = BrowserClient(messenger: engine.messenger, webSessions: webSessions)
    uiHost = CoreUiHost(presenter: presenter, webSessions: webSessions)
    if let hint = LaunchHint.load() {
      if let language = hint.language.flatMap(AppLanguage.init(rawValue:)) { apply(language) }
      if let theme = hint.theme.flatMap(ThemeChoice.init(rawValue:)) { applyTheme(theme) }
      BrandPalette.shared.apply(hint.brandSeed)
      launchHint = hint
    }
  }

  func start() {
    engine.start(uiHost: uiHost, transfers: transfers, mail: mailCenter)
  }

  func apply(_ language: AppLanguage) {
    L10n.use(language)
    self.language = language
    remember { $0.language = language.rawValue }
  }

  func applyTheme(_ theme: ThemeChoice) {
    self.theme = theme
    colorScheme =
      switch theme {
      case .system: nil
      case .light: .light
      case .dark: .dark
      }
    remember { $0.theme = theme.rawValue }
  }

  func rememberBrand(_ seed: Int64?) {
    remember { $0.brandSeed = seed }
  }

  /// 核心回答了登入與同意的狀態；語言與外觀取目前套用的。
  func rememberLaunch(signedIn: Bool, agreed: Bool) {
    let hint = LaunchHint(
      signedIn: signedIn, agreed: agreed, language: language?.rawValue, theme: theme?.rawValue,
      brandSeed: BrandPalette.shared.seed)
    guard hint != launchHint else { return }
    launchHint = hint
    hint.save()
  }

  private func remember(_ change: (inout LaunchHint) -> Void) {
    guard var hint = launchHint else { return }
    change(&hint)
    guard hint != launchHint else { return }
    launchHint = hint
    hint.save()
  }

  /// 把課表寫給小工具，內容沒變就什麼都不做。
  func refreshWidgets() {
    widgets.refresh(language: language ?? .system)
  }

  /// 先清 Dart 那一側，再清 WebView 的登入狀態，最後回登入頁。小工具上的課表也跟著清掉。
  func signOut() async {
    try? await more.logout()
    await WebHost.clearWebsiteData()
    mailCenter.reset()
    refreshWidgets()
    signOutCount += 1
  }
}
