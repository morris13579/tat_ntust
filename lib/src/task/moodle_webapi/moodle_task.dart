import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/cache_task.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';

class MoodleTask<T> extends CacheTask<T> {
  static bool _isLogin = false;

  bool useMoodleWebApi = Model.instance.getOtherSetting().useMoodleWebApi;

  MoodleTask(name) : super(name);

  static set isLogin(bool value) {
    _isLogin = value;
  }

  @override
  Future<TaskStatus> execute() async {
    String taskName = (useMoodleWebApi) ? "MoodleWebApiTask " : "MoodleTask ";
    name = taskName + name;
    if (_isLogin) return TaskStatus.Success;
    if (useMoodleWebApi) {
      String account = Model.instance.getAccount();
      String password = Model.instance.getPassword();
      if (account.isEmpty || password.isEmpty) {
        return TaskStatus.GiveUp;
      }
      super.onStart(R.current.loginMoodleWebApi);
      var value = await MoodleWebApiConnector.login(account, password);
      super.onEnd();
      if (value == MoodleWebApiConnectorStatus.LoginSuccess) {
        _isLogin = true;
      } else {
        return await onError(R.current.loginMoodleWebApiError);
      }
    }
    String account = Model.instance.getAccount();
    String password = Model.instance.getPassword();
    if (account.isEmpty || password.isEmpty) {
      return TaskStatus.GiveUp;
    }
    super.onStart(R.current.loginMoodle);
    var value = await MoodleConnector.login(account, password);
    super.onEnd();
    if (value == MoodleConnectorStatus.LoginSuccess) {
      _isLogin = true;
      return TaskStatus.Success;
    } else {
      return await onError(R.current.loginMoodleError);
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
