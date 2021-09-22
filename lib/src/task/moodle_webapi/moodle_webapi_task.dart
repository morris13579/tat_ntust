import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/dialog_task.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';

class MoodleWebApiTask<T> extends DialogTask<T> {
  static bool _isLogin = false;

  MoodleWebApiTask(name) : super(name);

  static set isLogin(bool value) {
    _isLogin = value;
  }

  @override
  Future<TaskStatus> execute() async {
    if (_isLogin) return TaskStatus.Success;
    name = "MoodleWebApiTask " + name;
    String account = Model.instance.getAccount();
    String password = Model.instance.getPassword();
    if (account.isEmpty || password.isEmpty) {
      return TaskStatus.GiveUp;
    }
    super.onStart(R.current.loginMoodle);
    var value = await MoodleWebApiConnector.login(account, password);
    super.onEnd();
    if (value == MoodleWebApiConnectorStatus.LoginSuccess) {
      _isLogin = true;
      return TaskStatus.Success;
    } else {
      return await onError(R.current.loginMoodleError + "\n如果一直發生錯誤，請嘗試到設定中關閉Moodle WebAPI");
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
