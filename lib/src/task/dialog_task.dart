import 'package:connectivity/connectivity.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:flutter_app/ui/other/my_progress_dialog.dart';

import 'task.dart';

class DialogTask<T> extends Task<T> {
  DialogTask(String name) : super(name);
  bool openLoadingDialog = true;

  @override
  Future<TaskStatus> execute() async {
    return TaskStatus.success;
  }

  void onStart(String message) {
    if (openLoadingDialog) {
      MyProgressDialog.progressDialog(message);
    }
  }

  void onEnd() {
    if (openLoadingDialog) {
      MyProgressDialog.hideProgressDialog();
    }
  }

  Future<TaskStatus> onError(String message) async {
    ErrorDialogParameter parameter = ErrorDialogParameter(
      desc: message,
    );
    return await onErrorParameter(parameter);
  }

  Future<TaskStatus> onErrorParameter(ErrorDialogParameter parameter) async {
    //可自定義處理Error
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        parameter = ErrorDialogParameter(
          desc: R.current.networkError,
        );
      }
      return (await ErrorDialog(parameter).show())
          ? TaskStatus.restart
          : TaskStatus.giveUp;
    } catch (e) {
      return TaskStatus.giveUp;
    }
  }
}
