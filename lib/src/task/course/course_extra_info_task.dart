import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/task/dialog_task.dart';

import '../task.dart';

class CourseExtraInfoTask extends DialogTask<CourseExtraInfoJson> {
  final id;

  CourseExtraInfoTask(this.id) : super("CourseExtraInfoTask");

  @override
  Future<TaskStatus> execute() async {
    super.onStart(R.current.getCourseDetail);
    CourseExtraInfoJson value = await CourseConnector.getCourseExtraInfo(id);
    super.onEnd();
    if (value != null) {
      result = value;
      return TaskStatus.Success;
    } else {
      return await super.onError(R.current.getCourseDetailError);
    }
  }
}
