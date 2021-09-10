import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';

import '../task.dart';
import 'moodle_webapi_task.dart';

class MoodleWebApiCourseMessageTask
    extends MoodleWebApiTask<MoodleModForumGetForumDiscussionsPaginated> {
  final String id;

  MoodleWebApiCourseMessageTask(this.id)
      : super("MoodleWebApiCourseMessageTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      MoodleModForumGetForumDiscussionsPaginated value;
      super.onStart(R.current.getMoodleCourseAnnouncement);
      value = await MoodleWebApiConnector.getCourseMessage(id);
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
