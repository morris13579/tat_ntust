import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/model/moodle/moodle_branch.dart';

import '../task.dart';
import 'moodle_task.dart';

class MoodleCourseBranchTask extends MoodleTask<MoodleBranchJson> {
  final MoodleCourseDirectoryInfo info;

  MoodleCourseBranchTask(this.info) : super("MoodleCourseBranchTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      MoodleBranchJson value;
      super.onStart(R.current.getMoodleCourseBranch);
      value = await MoodleConnector.getCourseBranch(info);
      super.onEnd();
      if (value != null) {
        result = value;
        return TaskStatus.Success;
      } else {
        return await super.onError(R.current.getMoodleCourseBranchError);
      }
    }
    return status;
  }
}
