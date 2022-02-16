import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/task/score/cache_task.dart';
import 'package:flutter_app/src/task/task.dart';

class CourseExtraInfoTask extends CacheTask<CourseExtraInfoJson> {
  final id;
  final SemesterJson semester;

  CourseExtraInfoTask(this.id, this.semester) : super("CourseExtraInfoTask") {
    key = "cache_course_extra_$id";
  }

  @override
  Future<TaskStatus> execute() async {
    super.onStart(R.current.getCourseDetail);
    CourseExtraInfoJson? value =
        await CourseConnector.getCourseExtraInfo(id, semester);
    super.onEnd();
    if (value != null) {
      result = value;
      return TaskStatus.Success;
    } else {
      return await super.onError(R.current.getCourseDetailError);
    }
  }
}
