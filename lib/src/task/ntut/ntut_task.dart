import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:flutter_app/ui/pages/ntust_login_page.dart';
import 'package:get/get.dart';

import '../dialog_task.dart';

class NTUTTask<T> extends DialogTask<T> {
  static bool _remindPasswordExpiredWarning = false;
  static bool _isLogin = false;

  NTUTTask(name) : super(name);

  static set isLogin(bool value) {
    _isLogin = value;
  }

  @override
  Future<TaskStatus> execute() async {
    if (_isLogin) return TaskStatus.Success;
    name = "NTUTTask " + name;
    String account = Model.instance.getAccount();
    String password = Model.instance.getPassword();
    if (account.isEmpty || password.isEmpty) {
      return TaskStatus.GiveUp;
    }
    var value;
    value = await Get.to(
      () => LoginNTUSTPage(
        username: account,
        password: password,
      ),
    );
    value ??= false;
    if (value) {
      _isLogin = true;
      return TaskStatus.Success;
    } else {
      return await onError(R.current.unknownError);
    }
  }

  @override
  Future<TaskStatus> onError(String message) {
    _isLogin = false;
    return super.onError(message);
  }

  @override
  Future<TaskStatus> onErrorParameter(ErrorDialogParameter parameter) {
    _isLogin = false;
    return super.onErrorParameter(parameter);
  }
}
