import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';

import '../task.dart';
import 'moodle_support_task.dart';

class MoodleCourseDirectoryTask
    extends MoodleSupportTask<List<MoodleCoreCourseGetContents>> {
  final courseId;

  MoodleCourseDirectoryTask(this.courseId)
      : super("MoodleCourseDirectoryTask", courseId);

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      List<MoodleCoreCourseGetContents>? value;
      super.onStart(R.current.getMoodleCourseDirectory);
      if (useMoodleWebApi)
        value = await MoodleWebApiConnector.getCourseDirectory(findId);
      else
        value = await MoodleConnector.getCourseDirectory(findId);
      super.onEnd();
      if (value != null) {
        result = value;
        return TaskStatus.Success;
      } else {
        return await super.onError(R.current.getMoodleCourseDirectoryError);
      }
    }
    return status;
  }
}