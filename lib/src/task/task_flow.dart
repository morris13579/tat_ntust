import 'package:connectivity/connectivity.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/task/course/course_system_task.dart';
import 'package:flutter_app/src/task/moodle/moodle_task.dart';
import 'package:flutter_app/src/task/ntust/ntust_task.dart';
import 'package:flutter_app/ui/other/my_toast.dart';

import 'task.dart';

typedef OnSuccessCallBack = Function(Task);

class TaskFlow {
  late List<Task> _queue;
  late List<Task> _completeTask;
  late List<Task> _failTask;
  OnSuccessCallBack? callback;

  static resetLoginStatus() {
    NTUSTTask.isLogin = false;
    CourseSystemTask.isLogin = false;
    MoodleTask.isLogin = false;
  }

  int get length {
    return _queue.length;
  }

  List<Task> get completeTask {
    return _completeTask;
  }

  TaskFlow() {
    _queue = [];
    _completeTask = [];
    _failTask = [];
  }

  void addTask(Task task) {
    _queue.add(task);
  }

  static Future<bool> checkConnectivity() async {
    var connectivityResult = await (new Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    return true;
  }

  Future<bool> start({bool checkNetwork: true}) async {
    if (checkNetwork && !await checkConnectivity()) {
      MyToast.show(R.current.pleaseConnectToNetwork);
      return false;
    }
    bool success = true;
    while (_queue.length > 0) {
      Task task = _queue.first;
      TaskStatus status = await task.execute();
      switch (status) {
        case TaskStatus.Success:
          _queue.removeAt(0);
          _completeTask.add(task);
          if (callback != null) {
            callback!(task);
          }
          break;
        case TaskStatus.GiveUp:
          _failTask.addAll(_queue);
          _queue = [];
          success = false;
          break;
        case TaskStatus.Restart:
          break;
      }
    }
    String log = "success";
    for (Task task in _completeTask) {
      log += '\n--' + task.name;
    }
    if (!success) {
      log += "\nfail";
      for (Task task in _failTask) {
        log += '\n--' + task.name;
      }
    }
    _completeTask = [];
    _failTask = [];
    Log.d(log);
    return success;
  }
}
