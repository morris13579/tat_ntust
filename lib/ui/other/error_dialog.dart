//  error_dialog.dart
//  用於顯示錯誤視窗
//  Created by morris13579 on 2020/02/12.
//  Copyright © 2020 morris13579 All rights reserved.
//

import 'dart:async';

import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/service/error_dialog_parameter.dart';
import 'package:flutter_app/ui/other/tat_dialog.dart';
import 'package:get/get.dart';

export 'package:flutter_app/src/service/error_dialog_parameter.dart';

/// [ErrorDialogParameter] 的顯示端。骨架是 [TatDialog]，這裡只負責把參數翻成
/// 它的欄位，並在這一刻才補上 `R.current` 的預設值——參數類別是在其他語言環境
/// 建的，提早取字串會取到舊語系。
class ErrorDialog {
  ErrorDialogParameter parameter;

  ErrorDialog(this.parameter);

  Future<bool> show() async {
    final title = parameter.title ?? R.current.alertError;
    final btnOkText = parameter.btnOkText ?? R.current.restart;
    final btnCancelText = parameter.btnCancelText ?? R.current.cancel;

    final result = await showTatDialog<bool>(
      dialog: TatDialog(
        title: title,
        body: parameter.desc,
        kind: parameter.kind ?? TatDialogKind.error,
        destructive: parameter.destructive,
        primary: parameter.offOkBtn
            ? null
            : TatDialogAction(
                label: btnOkText,
                onPressed: _press(parameter.btnOkOnPress, parameter.okResult),
              ),
        secondary: parameter.offCancelBtn
            ? null
            : TatDialogAction(
                label: btnCancelText,
                onPressed:
                    _press(parameter.btnCancelOnPress, parameter.cancelResult),
              ),
      ),
    );
    // 不是 `?? false`：只有一顆按鈕的對話框會把 okResult 設成 false，
    // 「沒有回傳值」該退回呼叫端指定的 cancelResult。
    return result ?? parameter.cancelResult;
  }

  /// 呼叫端沒給按法時，預設就是關掉並回報自己那一邊的結果。
  FutureOr<void> Function() _press(dynamic Function()? custom, bool result) {
    final action = custom ?? () => Get.back<bool>(result: result);
    return () {
      action();
    };
  }
}
