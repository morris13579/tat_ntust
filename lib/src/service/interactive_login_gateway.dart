import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/enum/ntust_login_status.dart';

/// 需要真人的登入。
///
/// 真正的切線不是 Dio 對 WebView，是**非互動對互動**。非互動的嘗試可以在
/// 任何地方跑；一旦需要使用者親自操作（Turnstile 要點、密碼打錯要重打），
/// 就必須有人把畫面推到最前面——而那件事只有 UI 層做得到。
///
/// 它同時是分層的必要：非 UI 層直接 import 登入頁會是 `tool/deps.py` 白名單
/// 裡不存在的配對種類，CI 直接 FAIL。閘道是那條 import 唯一的去處。
///
/// 實作在 `lib/ui/auth/get_interactive_login_gateway.dart`，由 `main.dart`
/// 在 `runApp` **之前**安裝——不能放在 `GetMaterialApp.onReady`，
/// 那比第一個讀取者晚（見 main.dart 的註解與 test/main_startup_order_test.dart）。
abstract class InteractiveLoginGateway {
  /// 尚未安裝時是會拋的 [UninstalledInteractiveLoginGateway]。
  static InteractiveLoginGateway instance =
      const UninstalledInteractiveLoginGateway();

  /// 開一個可見的 ssoam2 登入頁。使用者按返回鍵放棄時回 null。
  Future<NtustInteractiveLoginResult?> signInNtust({
    required String account,
    required String password,
  });

  /// 開一個可見的 Moodle 登入頁，取得 wstoken。放棄或失敗回 null。
  Future<MoodleTokenEntity?> signInMoodle({
    required String account,
    required String password,
  });
}

/// [InteractiveLoginGateway.signInNtust] 的結果。
class NtustInteractiveLoginResult {
  const NtustInteractiveLoginResult({required this.status, this.message});

  final NTUSTLoginStatus status;

  /// 站台回報的錯誤訊息（例如帳號密碼錯誤），沒有就是 null。
  final String? message;
}

/// 尚未安裝實作時的佔位。任何呼叫都會拋。
///
/// 與 `AuthSession` 的 `UninstalledAuthSession` 同慣例：忘了安裝要當場炸在
/// 啟動路徑，而不是靜靜地變成「登入失敗」。
class UninstalledInteractiveLoginGateway implements InteractiveLoginGateway {
  const UninstalledInteractiveLoginGateway();

  Never _fail() =>
      throw StateError('InteractiveLoginGateway.instance 尚未安裝。正式環境應在 main() 裡、'
          'runApp 之前指派實作；測試請指派一個假的。');

  @override
  Future<NtustInteractiveLoginResult?> signInNtust({
    required String account,
    required String password,
  }) =>
      _fail();

  @override
  Future<MoodleTokenEntity?> signInMoodle({
    required String account,
    required String password,
  }) =>
      _fail();
}
