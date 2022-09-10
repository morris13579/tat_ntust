import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/src/connector/ntust_login_page.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/cache_task.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:get/get.dart';

class NTUSTTask<T> extends CacheTask<T> {
  static bool _isLogin = false;

  NTUSTTask(name) : super(name);

  static set isLogin(bool value) {
    _isLogin = value;
  }

  @override
  Future<TaskStatus> execute() async {
    if (_isLogin) return TaskStatus.success;
    name = "NTUSTTask $name";
    String account = Model.instance.getAccount();
    String password = Model.instance.getPassword();
    if (account.isEmpty || password.isEmpty) {
      return TaskStatus.giveUp;
    }
    Map<String, dynamic>? value;
    NTUSTLoginStatus status;
    String? message;
    super.onStart(R.current.loginNTUST);
    value = await NTUSTConnector.login(account, password);
    super.onEnd();

    if (value["status"] == NTUSTLoginStatus.fail) {
      if (value["message"] != null) {
        MyToast.show(value["message"]);
      }
      value = await Get.to(
        () => LoginNTUSTPage(
          username: account,
          password: password,
        ),
      );
    }

    if (value == null) {
      status = NTUSTLoginStatus.fail;
    } else {
      status = value["status"];
      message = value["message"];
    }
    if (status == NTUSTLoginStatus.success) {
      _isLogin = true;
      return TaskStatus.success;
    } else {
      return await _onError(status, message: message);
    }
  }

  Future<TaskStatus> _onError(NTUSTLoginStatus value, {String? message}) async {
    ErrorDialogParameter parameter = ErrorDialogParameter(
      desc: "",
    );
    switch (value) {
      case NTUSTLoginStatus.fail:
        parameter.dialogType = DialogType.error;
        parameter.desc = message ?? R.current.unknownError;
        if (message != null) {
          //帳號輸入錯誤的可能
          parameter.btnOkText = R.current.setting;
          parameter.okResult = false;
          parameter.btnOkOnPress = () {
            RouteUtils.toLoginScreen()
                .then((value) => Get.back<bool>(result: true));  //close dialog
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
