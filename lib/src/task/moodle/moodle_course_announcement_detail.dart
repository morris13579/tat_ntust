import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';

import '../task.dart';
import 'moodle_task.dart';

class MoodleCourseAnnouncementDetailTask extends MoodleTask<String> {
  final String url;

  MoodleCourseAnnouncementDetailTask(this.url)
      : super("MoodleCourseAnnouncementDetailTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      super.onStart(R.current.getMoodleCourseAnnouncement);
      String value = await MoodleConnector.getCourseAnnouncementDetail(url);
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
