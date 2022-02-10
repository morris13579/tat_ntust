import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/model/moodle/moodle_info.dart';
import 'package:flutter_app/src/util/language_utils.dart';

import '../task.dart';
import 'moodle_task.dart';

class MoodleCourseInfoTask extends MoodleTask<MoodleInfoJson> {
  final MoodleCourseDirectoryInfo info;

  MoodleCourseInfoTask(this.info) : super("MoodleCourseInfoTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      MoodleInfoJson? value;
      super.onStart(R.current.getMoodleCourseInfo);
      value = await MoodleConnector.getCourseInfo(info);
      super.onEnd();
      if (value != null) {
        try {
          for (var i in value.children) {
            i.link += (LanguageUtils.getLangIndex() == LangEnum.zh)
                ? "&lang=zh_tw"
                : "&lang=en";
          }
        } catch (e) {}
        result = value;
        return TaskStatus.Success;
      } else {
        return await super.onError(R.current.getMoodleCourseInfoError);
      }
    }
    return status;
  }
}
