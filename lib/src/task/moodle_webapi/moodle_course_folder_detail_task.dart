import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/task/task.dart';

import 'moodle_task.dart';

class MoodleCourseFolderDetailTask extends MoodleTask<Modules> {
  final Modules modules;

  MoodleCourseFolderDetailTask(this.modules)
      : super("MoodleCourseFolderDetailTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.success) {
      Modules value;
      super.onStart(R.current.getMoodleCourseFolderDetail);
      value = await MoodleConnector.getFolder(modules);
      modules.folderIsNone = false;
      super.onEnd();
      result = value;
      return TaskStatus.success;
      //return await super.onError(R.current.getMoodleCourseFolderDetailError);
    }
    return status;
  }
}
