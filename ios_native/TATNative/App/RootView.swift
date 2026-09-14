import SwiftUI

/// 共用容器裡有帳號就直接進主畫面，與 Flutter 版同一個判準。
///
/// 核心上一次回答過（`LaunchHint`）就先照那一次進畫面，引擎在背景起來，由畫面自己的載入狀態陪著等；
/// 沒有紀錄時（第一次啟動）才停在和系統啟動畫面一樣的畫面上等核心。
struct RootView: View {
  @Environment(AppEnvironment.self) private var app
  /// nil 代表核心還沒回答，先照 `LaunchHint`。
  @State private var phase: Phase?
  @State private var started = false
  /// 核心回答過 `launch` 才記下畫面；核心沒回答時的退路不算數。
  @State private var coreAnswered = false
  @State private var loginSheet = false
  /// 同意閘門之後要去哪裡。
  @State private var signedIn = false

  private enum Phase { case launching, agreement, login, main }

  private var current: Phase {
    if let phase { return phase }
    guard let hint = app.launchHint, hint.agreed else { return .launching }
    return hint.signedIn ? .main : .login
  }

  var body: some View {
    content
      // L10n 是全域的，SwiftUI 不知道字串變了，換語言時整棵重建。
      .id(app.language)
      .preferredColorScheme(app.colorScheme)
      // 瀏覽器以外都不要捲軸；瀏覽器是 WKWebView，不受這個影響。
      .scrollIndicators(.hidden)
      .task { await launch() }
      .onChange(of: app.signOutCount) { phase = .login }
      .onChange(of: phase) { _, phase in
        guard coreAnswered else { return }
        switch phase {
        case .main: app.rememberLaunch(signedIn: true, agreed: true)
        case .login: app.rememberLaunch(signedIn: false, agreed: true)
        case .agreement: app.rememberLaunch(signedIn: signedIn, agreed: false)
        case .launching, nil: break
        }
      }
      .onChange(of: BrandPalette.shared.seed) { _, seed in app.rememberBrand(seed) }
      .onChange(of: app.presenter.loginRequests) {
        // 不在主畫面時沒有東西可以蓋，直接當成關掉，等待的人才不會卡住。
        if current == .main { loginSheet = true } else { app.presenter.loginClosed() }
      }
      .sheet(isPresented: $loginSheet, onDismiss: app.presenter.loginClosed) {
        NavigationStack {
          LoginView(model: LoginModel(core: app.core, presenter: app.presenter)) {
            loginSheet = false
          }
          .toolbar { SheetCloseButton { loginSheet = false } }
        }
      }
  }

  @ViewBuilder private var content: some View {
    switch current {
    case .launching:
      // 跟系統啟動畫面同一張圖、同一個底色（Info.plist 的 UILaunchScreen）。系統的圖置中在整個螢幕，
      // 不是安全區域，這裡也要忽略安全區域，否則圖會往下偏。
      ZStack {
        Color("SplashBackground")
        Image("LaunchImage")
      }
      .ignoresSafeArea()
    case .agreement:
      PrivacyAgreementView {
        Task {
          try? await app.core.agreePrivacyPolicy()
          phase = signedIn ? .main : .login
        }
      }
    case .login:
      LoginView(model: LoginModel(core: app.core, presenter: app.presenter)) { phase = .main }
    case .main:
      MainTabView()
    }
  }

  private func launch() async {
    guard !started else { return }
    started = true
    // coreMain 還沒跑完時訊息會排隊，核心起來才回答；其他呼叫在 CoreGate 等這一支。
    guard let launch = try? await app.core.launch() else {
      if app.language == nil { app.apply(.system) }
      phase = current == .launching ? .login : current
      return
    }
    coreAnswered = true
    if let language = launch.language {
      if language != app.language { app.apply(language) }
    } else {
      // 和 Flutter 版的 LanguageUtils.init 一樣：沒選過就用系統的，並寫回設定。
      app.apply(.system)
      try? await app.core.setLanguage(.system)
    }
    signedIn = !launch.account.isEmpty
    // 照上一次進了主畫面，其實已經沒有帳號：先回登入頁，別讓核心的登入要求蓋在主畫面上。
    if current == .main && !signedIn { phase = .login }
    let theme = try? await app.more.theme()
    let color = try? await app.more.themeColor()
    // 照 `main.dart` 的 onReady：還沒同意隱私權條款的人，登入或進主畫面之前先過同意閘門。
    let needsAgreement = (try? await app.core.needsPrivacyAgreement()) == true
    // 外觀和畫面一起換：還停在啟動畫面時先換深淺色，啟動畫面會閃一下。
    if let theme { app.applyTheme(theme) }
    if let color { BrandPalette.shared.apply(color) }
    if needsAgreement {
      phase = .agreement
    } else {
      phase = signedIn ? .main : .login
    }
    app.refreshWidgets()
    #if DEBUG
    await WidgetPreview.renderIfRequested(app)
    #endif
  }
}
