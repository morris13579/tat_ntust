import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';

import '../task.dart';
import 'moodle_task.dart';

class MoodleMemberTask extends MoodleTask<List<MoodleUserInfo>> {
  final id;

  MoodleMemberTask(this.id) : super("MoodleMemberTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      List<MoodleUserInfo>? value;
      super.onStart(R.current.getMoodleMembers);
      value = await MoodleConnector.getMember(id);
      super.onEnd();
      if (value != null && value.length != 0) {
        result = value;
        return TaskStatus.Success;
      } else {
        return await super.onError(R.current.getMoodleMembersError);
      }
    }
    return status;
  }
}
