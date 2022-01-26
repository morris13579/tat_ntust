import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';

import '../task.dart';
import 'moodle_task.dart';

class MoodleScoreTask extends MoodleTask<List<MoodleScoreItem>> {
  final String id;

  MoodleScoreTask(this.id) : super("MoodleScoreTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      List<MoodleScoreItem>? value;
      super.onStart(R.current.getMoodleScore);
      value = await MoodleConnector.getScore(id);
      super.onEnd();
      if (MoodleConnector.id == null) {
        ErrorDialogParameter parameter = ErrorDialogParameter(
          title: R.current.warning,
          dialogType: DialogType.INFO,
          desc: R.current.unSupportThisClass,
          okResult: false,
          btnOkText: R.current.sure,
          offCancelBtn: true,
        );
        return await super.onErrorParameter(parameter);
      }
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
