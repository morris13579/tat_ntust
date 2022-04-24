import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/task/cache_task.dart';
import 'package:flutter_app/src/task/task.dart';

class CourseExtraInfoTask extends CacheTask<CourseExtraInfoJson> {
  final String id;
  final SemesterJson semester;

  CourseExtraInfoTask(this.id, this.semester) : super("CourseExtraInfoTask") {
    initCache("cache_course_extra", id);
  }

  @override
  Future<TaskStatus> execute() async {
    super.onStart(R.current.getCourseDetail);
    CourseExtraInfoJson? value =
        await CourseConnector.getCourseExtraInfo(id, semester);
    super.onEnd();
    if (value != null) {
      result = value;
      return TaskStatus.success;
    } else {
      return await super.onError(R.current.getCourseDetailError);
    }
  }
}
