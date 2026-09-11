import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/service/error_dialog_parameter.dart';

/// 使用者對錯誤對話框的選擇。
enum RetryDecision { retry, giveUp }

/// 一次進度框顯示的憑證。
///
/// 之所以需要「憑證」而不是一個全域的關閉函式：課程頁的三個分頁是並行載入的，
/// 沒有東西可以指名的話，先結束的那一個會把另外兩個的遮罩一起收掉，使用者
/// 以為載完了。`run()` 的 try/finally 要能「只關掉自己開的那一個」，就必須有
/// 東西可以指——就是這個 handle。
abstract class ProgressHandle {
  /// 只關掉這一個進度框。可以重複呼叫，第二次以後是 no-op。
  void dismiss();
}

/// 什麼都不做的 handle，給測試與 headless 環境用。
class NoopProgressHandle implements ProgressHandle {
  const NoopProgressHandle();

  @override
  void dismiss() {}
}

/// Task 層唯一被允許用來碰 UI 的介面。
///
/// 實作在 `lib/ui/service/get_task_ui_delegate.dart`，由 main.dart 在啟動時
/// 指派給 [TaskUiDelegate.instance]。預設是 [NoopTaskUiDelegate]，所以
/// 測試不需要註冊任何東西，非 UI 層也不必依賴 GetX 的服務定位。
abstract class TaskUiDelegate {
  static TaskUiDelegate instance = const NoopTaskUiDelegate();

  /// 顯示進度框，回傳只關掉這一個的憑證。
  ///
  /// 這是顯示進度框唯一的入口：沒有「全部關掉」的另一半，漏關的遮罩才不會
  /// 變成一塊吃掉所有觸控、只能靠下一次全域關閉收拾的畫面。
  ProgressHandle beginProgress(String message);

  Future<RetryDecision> confirmRetry(ErrorDialogParameter parameter);

  void toast(String message);

  /// 請使用者從幾個選項裡挑一個。key 是顯示的字，value 是要回傳的值。
  ///
  /// 取消或沒有實作時回 null，那代表「使用者沒有選」——呼叫端不可以自己挑一個
  /// 頂替。行事曆下載途中要問學期就是走這條。
  Future<String?> chooseOne(String title, Map<String, String> options);

  /// 請使用者手動挑一個學期。取消時回 null。
  ///
  /// [allowNull] 為 false 時，使用者沒有選就回「現在這個學期」而不是 null
  /// ——那是既有行為，呼叫端在那條路徑上沒有 null 的處理。
  ///
  /// 這個對話框是課表在三個學期來源全都拿不到資料、或存到的學期字串壞掉時
  /// 的最後手段。走這個介面而不是直接 import widget：controller -> ui 是
  /// 上行邊。
  Future<SemesterJson?> chooseSemester({bool allowNull = false});

  /// 帶使用者去登入設定。
  ///
  /// 站台明確拒絕憑證（帳號或密碼錯）時的出口。
  Future<void> openLoginScreen();
}

/// 測試與 headless 環境用的空實作。
class NoopTaskUiDelegate implements TaskUiDelegate {
  const NoopTaskUiDelegate();

  @override
  ProgressHandle beginProgress(String message) => const NoopProgressHandle();

  @override
  Future<RetryDecision> confirmRetry(ErrorDialogParameter parameter) async =>
      RetryDecision.giveUp;

  @override
  Future<String?> chooseOne(String title, Map<String, String> options) async =>
      null;

  @override
  Future<SemesterJson?> chooseSemester({bool allowNull = false}) async => null;

  @override
  Future<void> openLoginScreen() async {}

  @override
  void toast(String message) {}
}
