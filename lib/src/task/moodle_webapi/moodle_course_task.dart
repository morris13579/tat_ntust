import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_task.dart';
import 'package:flutter_app/src/task/task.dart';

class MoodleCourseTask extends MoodleTask<List<String>> {
  final SemesterJson semester;

  MoodleCourseTask(this.semester): super("MoodleCourseTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();

    if (status == TaskStatus.success) {
      var test = await MoodleWebApiConnector.getCourseIds(semester);
      super.onEnd();
      result = test;
      return TaskStatus.success;
    }

    return status;
  }
}