import 'package:flutter_app/src/service/task_ui_delegate.dart';

/// 舊的 toast 入口，現在只是轉接頭：真正顯示的是 UI 層的 `TatToast`。
///
/// 走 [TaskUiDelegate] 而不是直接叫 `TatToast`，`lib/src` 才不會產生指向
/// `lib/ui` 的上行邊。呼叫端全部改成直接用 [TaskUiDelegate.instance] 之後
/// 這個檔案就能刪掉。
class MyToast {
  MyToast._();

  static void show(String message) => TaskUiDelegate.instance.toast(message);
}
