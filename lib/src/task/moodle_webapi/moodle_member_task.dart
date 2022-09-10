import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/connector/moodle_old_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:flutter_app/ui/other/my_toast.dart';

import 'moodle_support_task.dart';

class MoodleMemberTask
    extends MoodleSupportTask<List<MoodleCoreEnrolGetUsers>> {
  final String courseId;
  final SemesterJson semester;

  MoodleMemberTask(this.courseId, this.semester)
      : super("MoodleMemberTask", courseId) {
    initCache("cache_moodle_member", courseId);
  }

  @override
  Future<TaskStatus> execute() async {
    List<MoodleCoreEnrolGetUsers>? value;
    if (int.parse(semester.year) <= 110 && int.parse(semester.semester) <= 1) {
      MyToast.show("Use Old Moodle");
      super.onStart(R.current.getMoodleMembers);
      await MoodleOldConnector.login(
          Model.instance.getAccount(), Model.instance.getPassword());
      value = await MoodleOldConnector.getMember(courseId);
      super.onEnd();
      if (value != null && value.isNotEmpty) {
        result = value;
        return TaskStatus.success;
      } else {
        return await super.onError(R.current.getMoodleMembersError);
      }
    }
    TaskStatus status = await super.execute();
    if (status == TaskStatus.success) {
      super.onStart(R.current.getMoodleMembers);
      if (useMoodleWebApi) {
        value = await MoodleWebApiConnector.getMember(findId);
      } else {
        value = await MoodleConnector.getMember(findId);
      }
      super.onEnd();
      if (value != null && value.isNotEmpty) {
        result = value;
        return TaskStatus.success;
      } else {
        return await super.onError(R.current.getMoodleMembersError);
      }
    }
    return status;
  }
}
