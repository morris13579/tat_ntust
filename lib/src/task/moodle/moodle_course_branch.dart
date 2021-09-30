import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/model/moodle/moodle_branch.dart';
import 'package:flutter_app/src/util/language_utils.dart';

import '../task.dart';
import 'moodle_task.dart';

class MoodleCourseBranchTask extends MoodleTask<MoodleBranchJson> {
  final MoodleCourseDirectoryInfo info;

  MoodleCourseBranchTask(this.info) : super("MoodleCourseBranchTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      MoodleBranchJson value;
      super.onStart(R.current.getMoodleCourseBranch);
      value = await MoodleConnector.getCourseBranch(info);
      try {
        for (var i in value.children) {
          if (i.link != null) {
            i.link += (LanguageUtils.getLangIndex() == LangEnum.zh)
                ? "&lang=zh_tw"
                : "&lang=en";
          }
        }
      } catch (e) {
        return await super.onError(R.current.getMoodleCourseBranchError);
      }
      super.onEnd();
      if (value != null) {
        result = value;
        return TaskStatus.Success;
      } else {
        return await super.onError(R.current.getMoodleCourseBranchError);
      }
    }
    return status;
  }
}
