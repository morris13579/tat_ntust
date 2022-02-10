import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/model/moodle/moodle_info.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';

import '../task.dart';
import 'moodle_task.dart';

class MoodleCourseAnnouncementTask
    extends MoodleTask<List<MoodleAnnouncementInfo>> {
  final String id;

  MoodleCourseAnnouncementTask(this.id) : super("MoodleCourseAnnouncementTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      List<MoodleAnnouncementInfo>? value;
      super.onStart(R.current.getMoodleCourseAnnouncement);
      value = await MoodleConnector.getCourseAnnouncement(id);
      super.onEnd();
      if (value != null) {
        result = value;
        return TaskStatus.Success;
      } else {
        return await super.onError(R.current.getMoodleCourseAnnouncementError);
      }
    }
    return status;
  }
}
