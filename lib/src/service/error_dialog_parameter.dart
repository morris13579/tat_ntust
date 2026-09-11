/// 對話框的種類。只影響標題前那顆圓點的顏色，沒有插圖、也沒有不同版面。
///
/// 這個 enum 刻意住在 `lib/src`：`main_controller.dart` 會傳它，而 controller
/// 不能 import `lib/ui`（tool/deps.py 的上行邊門檻是 0）。
enum TatDialogKind { error, warning, info, success }

/// 錯誤對話框的參數，純資料類。
///
/// 這個類別刻意不碰 `BuildContext`、不預設 `Get.back` 閉包、也不讀 `R.current`：
/// 所有預設值改由 UI 層在真正要顯示時補上（見 `lib/ui/other/error_dialog.dart`）。
/// 這樣 task 層才能不 import `lib/ui`。
///
/// 欄位保持可變，因為呼叫端是先建構再逐項覆寫。
class ErrorDialogParameter {
  String desc;
  String? title;
  String? btnOkText;
  String? btnCancelText;
  TatDialogKind? kind;

  /// 主鈕換成 error 底。取代以前「用 warning 種類暗示這個動作很危險」的做法。
  bool destructive;

  dynamic Function()? btnOkOnPress;
  dynamic Function()? btnCancelOnPress;
  bool offOkBtn;
  bool offCancelBtn;

  /// 除了重試之外，還要給一顆「設定」按鈕帶使用者去改帳號密碼。
  ///
  /// 只有站台明確拒絕憑證時才是 true。一般的抓取失敗重試就好，多一顆通往
  /// 登入頁的按鈕反而讓人以為是自己帳號有問題。
  bool offerLoginScreen = false;

  /// 按下確定時 `show()` 要回傳的值。預設 true，代表重試。
  bool okResult;

  /// 按下取消（或點掉對話框）時要回傳的值。預設 false，代表放棄。
  bool cancelResult;

  ErrorDialogParameter({
    required this.desc,
    this.title,
    this.btnOkText,
    this.btnCancelText,
    this.kind,
    this.destructive = false,
    this.btnCancelOnPress,
    this.btnOkOnPress,
    this.okResult = true,
    this.cancelResult = false,
    this.offOkBtn = false,
    this.offCancelBtn = false,
  }) : assert(!(offOkBtn && offCancelBtn), '兩顆按鈕都關掉會鎖死畫面：對話框點外面不關，使用者沒有出口');
}
