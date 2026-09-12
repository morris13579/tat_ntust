import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';
import 'package:flutter_app/ui/components/sheet/tat_bottom_sheet.dart';
import 'package:flutter_app/ui/components/toast/tat_toast.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:flutter_app/ui/pages/course_table/modal/manual_semester_dialog.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:get/get.dart';

/// [TaskUiDelegate] 的正式實作，由 main.dart 在啟動時指派。
class GetTaskUiDelegate implements TaskUiDelegate {
  const GetTaskUiDelegate();

  @override
  ProgressHandle beginProgress(String message) =>
      _OverlayProgressHandle(message);

  @override
  Future<RetryDecision> confirmRetry(ErrorDialogParameter parameter) async {
    // 站台明確拒絕憑證時，把「確定」換成通往登入設定的出口。「登入頁在哪」
    // 是 UI 這一層的責任。
    if (parameter.offerLoginScreen) {
      // 內文換成「為什麼失敗、下一步做什麼」。呼叫端傳進來的多半是抓取失敗的
      // 通用訊息，對「帳密被拒」這條路徑幫不上忙。
      parameter.desc = R.current.credentialRejectedDesc;
      parameter.btnOkText = R.current.setting;
      parameter.btnOkOnPress = () {
        // 改完帳密回來之後把對話框關掉並回報 retry——使用者剛剛才修正了
        // 讓它失敗的原因，直接重試才是他預期的。okResult 維持預設的 true，
        // 這條路徑才真的走得到重試。
        RouteUtils.toLoginScreen().then((_) => Get.back<bool>(result: true));
      };
    }
    return await ErrorDialog(parameter).show()
        ? RetryDecision.retry
        : RetryDecision.giveUp;
  }

  @override
  void toast(String message) => TatToast.show(message, kind: TatToastKind.info);

  @override
  Future<String?> chooseOne(String title, Map<String, String> options) =>
      selectOneDialog(title, options);

  @override
  Future<SemesterJson?> chooseSemester({bool allowNull = false}) =>
      manualSemesterDialog(allowSelectNull: allowNull);

  @override
  Future<void> openLoginScreen() => RouteUtils.toLoginScreen();
}

/// 從幾個選項裡挑一個；repository 只認得 [TaskUiDelegate.chooseOne]。
///
/// 下滑或點遮罩關掉會回 null，呼叫端必須把 null 當「使用者沒有選」處理，
/// 不可以自己挑一個頂替——那會給出他沒選過的東西。
Future<String?> selectOneDialog(String title, Map<String, String> options) {
  // 這一層沒有畫面自己的 context，借 Navigator 底下的 Overlay：從它往上找得到
  // Navigator，showModalBottomSheet 才推得出 route。
  final context = Get.key.currentState?.overlay?.context;
  if (context == null) return Future<String?>.value();
  return showTatSingleSelectSheet<String>(
    context: context,
    title: title,
    options: [
      for (final entry in options.entries)
        TatSheetOption<String>(label: entry.key, value: entry.value),
    ],
  );
}

/// 進度提示 ＝ 一顆掛著的膠囊 ＋ 一層擋點擊的蓋板。
///
/// **膠囊本身不在這裡畫。** 它和 toast 走同一條路（[TatToast.progress]），
/// 那是全 App 唯一一處把膠囊放上畫面的地方——先前這裡自己插一個 OverlayEntry
/// 手寫一顆，兩邊的圓角、內距與離底部的距離就各走各的，而且載入中又跳一句
/// 提示時兩顆會疊在同一個座標上。
///
/// 留在這裡的只有蓋板：登入、下載這幾件事進行中不該被亂點。它刻意是透明的
/// ——擋住點擊就夠了，不必把整個畫面壓暗。
class _OverlayProgressHandle implements ProgressHandle {
  _OverlayProgressHandle(String message) {
    _pill = TatToast.progress(message);
    final overlay = Get.key.currentState?.overlay;
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (context) => const Positioned.fill(child: AbsorbPointer()),
    );
    _blocker = entry;
    overlay.insert(entry);
  }

  TatToastHandle? _pill;
  OverlayEntry? _blocker;

  @override
  void dismiss() {
    // 欄位先清空再移除：呼叫端多關一次是 no-op，不必自己記有沒有關過。
    _pill?.dismiss();
    _pill = null;
    final entry = _blocker;
    _blocker = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}
