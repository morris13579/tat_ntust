import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import '../task.dart';
import 'moodle_support_task.dart';
import 'moodle_task.dart';

class MoodleScoreTask extends MoodleSupportTask<List<MoodleScoreItem>> {
  final courseId;

  MoodleScoreTask(this.courseId) : super("MoodleScoreTask", courseId);

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      List<MoodleScoreItem>? value;
      super.onStart(R.current.getMoodleScore);
      if (useMoodleWebApi)
        value = await MoodleWebApiConnector.getScore(findId);
      else
        value = await MoodleConnector.getScore(findId);
      super.onEnd();
      if (value != null && value.length != 0) {
        result = value;
        return TaskStatus.Success;
      } else {
        return await super.onError(R.current.getMoodleScoreError);
      }
    }
    return status;
  }
}
