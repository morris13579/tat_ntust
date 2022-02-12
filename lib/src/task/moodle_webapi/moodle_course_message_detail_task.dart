import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';

import '../task.dart';
import 'moodle_task.dart';

class MoodleCourseMessageDetailTask extends MoodleTask<String> {
  final url;

  MoodleCourseMessageDetailTask(this.url)
      : super("MoodleCourseMessageDetailTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      var value;
      super.onStart(R.current.getMoodleCourseAnnouncement);
      value = await MoodleConnector.getCourseAnnouncementDetail(url);
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
