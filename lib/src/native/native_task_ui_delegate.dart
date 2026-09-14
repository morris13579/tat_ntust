import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/generated/core_api.g.dart' as native;
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/service/error_dialog_parameter.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';

/// 原生版的 [TaskUiDelegate]：對話框、提示、進度框全部由 Swift 畫。
///
/// 核心層不可以自己開對話框（那是 controller → ui 的上行邊），原本走
/// `TaskUiDelegate`，在原生版就是走這條 channel。介面一字不改，
/// 所以 `run()`、`CourseModel` 那些呼叫端完全不知道換了實作。
class NativeTaskUiDelegate implements TaskUiDelegate {
  NativeTaskUiDelegate([native.TatCoreUiApi? api])
      : _api = api ?? native.TatCoreUiApi();

  final native.TatCoreUiApi _api;

  static void install([native.TatCoreUiApi? api]) =>
      TaskUiDelegate.instance = NativeTaskUiDelegate(api);

  @override
  ProgressHandle beginProgress(String message) =>
      _NativeProgressHandle(_api, message);

  @override
  Future<RetryDecision> confirmRetry(ErrorDialogParameter parameter) async {
    // 欄位一對一搬過去。**不要在這裡壓成「標題＋內文」**：destructive、
    // offerLoginScreen 與兩個 off*Btn 都會改變使用者的出口。
    //
    // `btnOkOnPress` / `btnCancelOnPress` 沒有過界：那兩個是 closure，
    // 而且 Flutter 版唯一會用到它們的路徑（offerLoginScreen 時跳登入頁）
    // 在原生版由 Swift 自己處理——它本來就知道登入頁在哪。
    final choice = await _api.confirmRetry(native.ErrorDialogRequest(
      desc: parameter.desc,
      title: parameter.title,
      okText: parameter.btnOkText,
      cancelText: parameter.btnCancelText,
      kind: switch (parameter.kind) {
        TatDialogKind.error => native.DialogKind.error,
        TatDialogKind.warning => native.DialogKind.warning,
        TatDialogKind.info => native.DialogKind.info,
        TatDialogKind.success => native.DialogKind.success,
        null => null,
      },
      destructive: parameter.destructive,
      hideOk: parameter.offOkBtn,
      hideCancel: parameter.offCancelBtn,
      offerLoginScreen: parameter.offerLoginScreen,
    ));
    return switch (choice) {
      native.RetryChoice.retry => RetryDecision.retry,
      native.RetryChoice.giveUp => RetryDecision.giveUp,
    };
  }

  @override
  void toast(String message) {
    // 回傳的 Future 刻意不 await：`TaskUiDelegate.toast` 是同步的，
    // 而「提示顯示完了沒」對呼叫端沒有意義。
    _api.toast(message).catchError((Object e, StackTrace s) {
      Log.eWithStack(e.toString(), s);
    });
  }

  @override
  Future<String?> chooseOne(String title, Map<String, String> options) =>
      _api.chooseOne(
        title,
        [
          for (final entry in options.entries)
            native.ChooseOption(label: entry.key, value: entry.value),
        ],
      );

  @override
  Future<SemesterJson?> chooseSemester({bool allowNull = false}) async {
    final picked = await _api.chooseSemester(allowNull);
    if (picked == null) return null;
    final parts = picked.split('-');
    if (parts.length != 2) {
      Log.e('chooseSemester 回了看不懂的格式：$picked');
      return null;
    }
    return SemesterJson(year: parts[0], semester: parts[1]);
  }

  @override
  Future<void> openLoginScreen() => _api.openLoginScreen();
}

/// 一次進度框。
///
/// `beginProgress` 是同步的，而過 channel 一定是非同步的，所以這裡先把
/// handle 的 Future 存起來，`dismiss` 再接上去關。**憑證不可以換成全域的
/// 「關掉」**：課程頁三個分頁並行載入，先結束的那一個會把另外兩個的遮罩
/// 一起收掉，使用者以為載完了。
class _NativeProgressHandle implements ProgressHandle {
  _NativeProgressHandle(this._api, String message)
      : _handle = _api.beginProgress(message);

  final native.TatCoreUiApi _api;
  final Future<int> _handle;
  bool _dismissed = false;

  @override
  void dismiss() {
    // 多呼叫幾次是安全的，與 Flutter 版的約定一致。
    if (_dismissed) return;
    _dismissed = true;
    _handle
        .then(_api.dismissProgress)
        .catchError((Object e, StackTrace s) => Log.eWithStack(e.toString(), s));
  }
}
