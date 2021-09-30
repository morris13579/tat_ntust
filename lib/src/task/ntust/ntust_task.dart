import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/src/connector/ntust_login_page.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:get/get.dart';

import '../dialog_task.dart';

class NTUSTTask<T> extends DialogTask<T> {
  static bool _isLogin = false;

  NTUSTTask(name) : super(name);

  static set isLogin(bool value) {
    _isLogin = value;
  }

  @override
  Future<TaskStatus> execute() async {
    if (_isLogin) return TaskStatus.Success;
    name = "NTUSTTask " + name;
    String account = Model.instance.getAccount();
    String password = Model.instance.getPassword();
    if (account.isEmpty || password.isEmpty) {
      return TaskStatus.GiveUp;
    }
    Map<String, dynamic>? value;
    NTUSTLoginStatus status;
    String? message;
    value = await Get.to(
      () => LoginNTUSTPage(
        username: account,
        password: password,
      ),
    );
    if (value == null) {
      status = NTUSTLoginStatus.Fail;
    } else {
      status = value["status"];
      message = value["message"];
    }
    if (status == NTUSTLoginStatus.Success) {
      _isLogin = true;
      return TaskStatus.Success;
    } else {
      return await _onError(status, message: message);
    }
  }

  Future<TaskStatus> _onError(NTUSTLoginStatus value, {String? message}) async {
    ErrorDialogParameter parameter = ErrorDialogParameter(
      desc: "",
    );
    switch (value) {
      case NTUSTLoginStatus.Fail:
        parameter.dialogType = DialogType.ERROR;
        parameter.desc = message ?? R.current.unknownError;
        if (message != null) {
          parameter.btnOkText = R.current.setting;
          parameter.btnOkOnPress = () {
            RouteUtils.toLoginScreen()
                .then((value) => Get.back<bool>(result: true));
          };
        }
        break;
      default:
        parameter.desc = R.current.unknownError;
        break;
    }
    return await onErrorParameter(parameter);
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
