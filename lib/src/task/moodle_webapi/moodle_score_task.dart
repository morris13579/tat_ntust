import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_score.dart';
import 'package:flutter_app/src/task/task.dart';

import 'moodle_support_task.dart';

class MoodleScoreTask extends MoodleSupportTask<List<MoodleScoreItem>> {
  final courseId;

  MoodleScoreTask(this.courseId) : super("MoodleScoreTask", courseId) {
    initCache("cache_moodle_score", courseId);
  }

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
