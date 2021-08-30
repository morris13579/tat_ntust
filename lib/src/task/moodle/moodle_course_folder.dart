import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';

import '../task.dart';
import 'moodle_task.dart';

class MoodleCourseFolderTask extends MoodleTask<List<FileInfo>> {
  final String url;

  MoodleCourseFolderTask(this.url) : super("MoodleCourseFolderTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      List<FileInfo> value;
      super.onStart(R.current.getMoodleCourseBranch);
      value = await MoodleConnector.getFolder(url);
      super.onEnd();
      if (value != null && value.length != 0) {
        result = value;
        return TaskStatus.Success;
      } else {
        return await super.onError(R.current.getMoodleCourseBranchError);
      }
    }
    return status;
  }
}
