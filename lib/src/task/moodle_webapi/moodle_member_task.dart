import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/task/task.dart';

import 'moodle_support_task.dart';

class MoodleMemberTask
    extends MoodleSupportTask<List<MoodleCoreEnrolGetUsers>> {
  final String courseId;

  MoodleMemberTask(this.courseId) : super("MoodleMemberTask", courseId) {
    initCache("cache_moodle_member", courseId);
  }

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.success) {
      List<MoodleCoreEnrolGetUsers>? value;
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
