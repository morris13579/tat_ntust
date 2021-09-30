import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';

import '../task.dart';
import 'moodle_webapi_task.dart';

class MoodleWebApiCourseDirectoryTask
    extends MoodleWebApiTask<List<MoodleCoreCourseGetContents>> {
  final String id;

  MoodleWebApiCourseDirectoryTask(this.id)
      : super("MoodleWebApiCourseDirectoryTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      List<MoodleCoreCourseGetContents>? value;
      super.onStart(R.current.getMoodleCourseDirectory);
      value = await MoodleWebApiConnector.getCourseDirectory(id);
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
