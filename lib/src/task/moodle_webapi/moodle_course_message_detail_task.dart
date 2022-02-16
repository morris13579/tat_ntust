import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/task/task.dart';

import 'moodle_task.dart';

class MoodleCourseMessageDetailTask extends MoodleTask<Discussions> {
  final Discussions discussion;

  MoodleCourseMessageDetailTask(this.discussion)
      : super("MoodleCourseMessageDetailTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      var value;
      super.onStart(R.current.getMoodleCourseAnnouncement);
      value = await MoodleConnector.getCourseAnnouncementDetail(
          discussion.userpictureurl, discussion);
      super.onEnd();
      if (value != null) {
        result = discussion;
        return TaskStatus.Success;
      } else {
        return await super.onError(R.current.getMoodleCourseAnnouncementError);
      }
    }
    return status;
  }
}
