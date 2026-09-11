import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/service/error_dialog_parameter.dart';
import 'package:flutter_app/src/service/task_ui_delegate.dart';

/// 記錄互動的 [TaskUiDelegate]。
///
/// 給要驗「有沒有彈框、有沒有開登入頁、有沒有吐 toast」的測試用；
/// 什麼都不想驗的測試用 [NoopTaskUiDelegate] 就好。
class RecordingUi implements TaskUiDelegate {
  /// 依序回傳給每一次 confirmRetry 的決定。用完之後一律 giveUp。
  final List<RetryDecision> decisions;

  final List<String> progressShown = [];
  final List<String> toasts = [];

  /// handle 被 dismiss 的次數。
  int dismissCalls = 0;

  int confirmCalls = 0;

  /// 最後一次 confirmRetry 收到的參數。
  ErrorDialogParameter? lastParameter;

  RecordingUi({List<RetryDecision>? decisions})
      : decisions = decisions ?? const [];

  @override
  ProgressHandle beginProgress(String message) {
    progressShown.add(message);
    return _RecordingProgressHandle(this);
  }

  @override
  Future<RetryDecision> confirmRetry(ErrorDialogParameter parameter) async {
    lastParameter = parameter;
    confirmCalls++;
    if (confirmCalls <= decisions.length) return decisions[confirmCalls - 1];
    return RetryDecision.giveUp;
  }

  @override
  void toast(String message) => toasts.add(message);

  @override
  Future<String?> chooseOne(String title, Map<String, String> options) async =>
      chooseOneResult;

  /// [chooseOne] 要回什麼。null 代表使用者取消。
  String? chooseOneResult;

  @override
  Future<void> openLoginScreen() async => openLoginCalls++;

  /// 「帶我去登入設定」被叫了幾次。
  int openLoginCalls = 0;

  @override
  Future<SemesterJson?> chooseSemester({bool allowNull = false}) async => null;
}

class _RecordingProgressHandle implements ProgressHandle {
  _RecordingProgressHandle(this._ui);

  final RecordingUi _ui;

  @override
  void dismiss() => _ui.dismissCalls++;
}
