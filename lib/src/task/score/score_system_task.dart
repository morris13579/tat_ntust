import 'package:flutter_app/src/task/ntust/ntust_task.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';

class ScoreSystemTask<T> extends NTUSTTask<T> {
  ScoreSystemTask(String name) : super(name);
  static bool isLogin = false;

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (isLogin) return TaskStatus.success;
    name = "ScoreSystemTask $name";
    if (status == TaskStatus.success) {
      isLogin = true;
    }
    return status;
  }

  @override
  Future<TaskStatus> onError(String message) {
    isLogin = false;
    return super.onError(message);
  }

  @override
  Future<TaskStatus> onErrorParameter(ErrorDialogParameter parameter) {
    isLogin = false;
    return super.onErrorParameter(parameter);
  }
}
