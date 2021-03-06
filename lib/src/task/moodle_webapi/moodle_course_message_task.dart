import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/task/task.dart';

import 'moodle_support_task.dart';

class MoodleCourseMessageTask
    extends MoodleSupportTask<MoodleModForumGetForumDiscussionsPaginated> {
  final String courseId;

  MoodleCourseMessageTask(this.courseId)
      : super("MoodleCourseMessageTask", courseId) {
    initCache("cache_moodle_message", courseId);
  }

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.success) {
      MoodleModForumGetForumDiscussionsPaginated? value;
      super.onStart(R.current.getMoodleCourseAnnouncement);
      if (useMoodleWebApi) {
        value = await MoodleWebApiConnector.getCourseAnnouncement(findId);
      } else {
        value = await MoodleConnector.getCourseAnnouncement(findId);
      }
      super.onEnd();
      if (value != null) {
        result = value;
        return TaskStatus.success;
      } else {
        return await super.onError(R.current.getMoodleCourseAnnouncementError);
      }
    }
    return status;
  }
}
