import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/task/task.dart';

import 'course_system_task.dart';

class CourseSearchTask extends CourseSystemTask<List<CourseMainInfoJson>> {
  final String search;
  SemesterJson semester;

  CourseSearchTask(this.semester, this.search) : super("CourseSearchTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    List<CourseMainInfoJson>? value;
    if (status == TaskStatus.success) {
      super.onStart(R.current.searching);
      value = await CourseConnector.searchCourse(semester, search);
      super.onEnd();
      if (value != null) {
        result = value;
        return TaskStatus.success;
      } else {
        return await super.onError(R.current.getCourseError);
      }
    }
    return status;
  }
}
