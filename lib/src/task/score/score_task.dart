import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/score_connector.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/task/score/score_system_task.dart';
import 'package:flutter_app/src/task/task.dart';

class ScoreTask extends ScoreSystemTask<ScoreRankJson> {
  ScoreTask() : super("ScoreTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.success) {
      ScoreRankJson? value;
      super.onStart(R.current.getScore);
      value = await ScoreConnector.getScoreRank();
      super.onEnd();
      if (value != null) {
        result = value;
        return TaskStatus.success;
      }
    }
    return await super.onError(R.current.getScoreError);
  }
}
