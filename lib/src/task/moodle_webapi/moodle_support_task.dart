import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_task.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';

class MoodleSupportTask<T> extends MoodleTask<T> {
  String _courseId;
  late String findId;
  static Map<String, String> recordSupport = {};

  MoodleSupportTask(name, this._courseId) : super("MoodleSupportTask " + name);

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      super.onStart(R.current.checkMoodleSupport);
      if (recordSupport.keys.contains(_courseId)) {
        findId = recordSupport[_courseId]!;
        return status;
      }
      try {
        if (useMoodleWebApi)
          findId = (await MoodleWebApiConnector.getCourseUrl(_courseId))!;
        else
          findId = (await MoodleConnector.getCourseUrl(_courseId))!;
        super.onEnd();
        recordSupport[_courseId] = findId;
      } catch (e) {
        super.onEnd();
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
    }
    return status;
  }
}
