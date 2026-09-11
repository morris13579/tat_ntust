/// 需要各自登入的外部系統。
///
/// **只有兩個，而且彼此獨立。** 存取 SSO 那邊的資料永遠不需要先登入 Moodle，
/// 反之亦然——拿 wsToken 的過程會經過 ssoam2，但那是登入頁的 WebView 自己
/// 完成的，不需要事先有 SSO session。
///
/// 成績系統刻意不是成員：它底下零網路呼叫，成績頁走的是 ScoreConnector 的
/// HeadlessInAppWebView，靠的就是 SSO cookie，等同於 [ntustSso]。多一個成員
/// 就多一顆會被漏清的旗標，換帳號後 B 會看到 A 的成績；列舉裡沒有它，這個
/// bug 在型別上就不可能發生。
enum SystemId {
  /// 學校的單一登入。全 App 兩個真正的憑證之一。
  ///
  /// 選課系統刻意不是成員：它沒有自己的憑證，只有一支探針（GET 首頁看 HTML
  /// 有沒有被踢回 SSO），而那件事 `run()` 的重試迴圈本來就在做。
  /// **兩個成員之間零相依**，`ensure` 因此不需要遞迴，也沒有相依展開。
  ntustSso,

  /// Moodle 的 Web API（wsToken）。全 App 兩個真正的憑證之二。
  ///
  /// **不相依於 [ntustSso]。** 拿 wsToken 的過程會經過 ssoam2，但那是
  /// `LoginMoodlePage` 的 WebView 自己完成的，不需要事先有 SSO session；
  /// 拿到之後用 wsToken 發請求也完全不碰 SSO cookie。
  moodleWebApi,
}

/// [AuthSession.ensure] 失敗的原因。
///
/// 刻意不直接回傳 repository 層的 `FailureReason`：auth 是 repository 的
/// 相依，反過來 import 會形成上行邊。對映由 `run()` 負責，只有一行。
enum AuthFailure {
  /// 沒有憑證，或憑證已經被清掉。不可重試，UI 應該畫登入按鈕。
  notSignedIn,

  /// 有憑證但登入失敗（密碼錯、驗證碼、學校端擋住）。可重試。
  loginFailed,
}

/// [AuthSession.ensure] 的失敗結果。
///
/// 只有 [failure] 是給程式判斷的；[message] 是站台自己回的字串，唯一的用途
/// 是顯示給使用者看。分成兩個欄位是因為錯誤對話框要靠 [message] 在不在決定
/// 要不要畫「設定」按鈕——有訊息代表站台明確拒絕了憑證，使用者得去改帳號密碼。
class AuthError {
  const AuthError(this.failure, {this.message});

  final AuthFailure failure;

  /// 站台回報的原因，例如「帳號或密碼錯誤」。沒有就是 null。
  final String? message;
}

/// 登入狀態的唯一所有者。登入狀態不該再有第二份逐一列舉的清單，那正是會
/// 漏掉一顆旗標的成因。
///
/// [instance] 預設是會拋例外的 [UninstalledAuthSession]，這樣忘記安裝時會
/// 立刻炸在啟動路徑上，而不是靜靜地當成「已經登入」。
abstract class AuthSession {
  static AuthSession instance = const UninstalledAuthSession();

  /// 確保 [requires] 裡的每個系統都已登入。回傳 null 代表全部就緒，
  /// 否則回傳失敗原因。
  ///
  /// [interactive] 為 false 時只做**安靜**的那一段：不開進度框、不開可見的
  /// 登入頁。給背景預載用——使用者沒有要求登入的時候，不該有東西蓋在他正在
  /// 看的畫面上。安靜模式失敗就失敗，呼叫端自己吞掉。
  Future<AuthError?> ensure(Set<SystemId> requires, {bool interactive = true});

  /// 盡力而為的登入，失敗不回報。給 `run()` 的 `optional` 使用。
  ///
  /// [interactive] 同 [ensure]。**背景路徑一定要傳 false**：`run()` 的
  /// `background` 只管它自己那一次 ensure，擋不到這裡。
  Future<void> tryEnsure(SystemId id, {bool interactive = true});

  /// 讓 [requires] 的登入狀態失效，下次 [ensure] 會重登。
  ///
  /// 「按下重試會靜默重新登入」唯一真正的語意。
  Future<void> invalidate(Set<SystemId> requires);

  /// 有沒有可用的憑證：帳號**與**密碼都非空。判準只有這一個——只有帳號
  /// 沒有密碼時，畫面會顯示「已登入」但任何一次登入都會失敗。
  ///
  /// `remote_config_utils` 與 `app_version` 在 util 層（util -> auth 是上行
  /// 邊），改為直接呼叫這個 getter 底下同一行的 `CredentialsStore
  /// .hasCredentials`。判準沒有分岔，只是抵達的路徑不同。
  bool get isSignedIn;
}

/// 尚未安裝實作時的佔位。任何呼叫都會拋。
class UninstalledAuthSession implements AuthSession {
  const UninstalledAuthSession();

  Never _fail() => throw StateError('AuthSession.instance 尚未安裝。正式環境應在啟動時指派實作，'
      '測試請指派 test/helpers/fake_auth_session.dart 的 FakeAuthSession。');

  @override
  Future<AuthError?> ensure(Set<SystemId> requires,
          {bool interactive = true}) =>
      _fail();

  @override
  Future<void> tryEnsure(SystemId id, {bool interactive = true}) => _fail();

  @override
  Future<void> invalidate(Set<SystemId> requires) => _fail();

  @override
  bool get isSignedIn => _fail();
}
