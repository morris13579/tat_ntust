import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/model/moodle/moodle_branch.dart';
import 'package:flutter_app/src/util/language_utils.dart';

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
      List<MoodleCourseDirectoryInfo>? vv;
      List<MoodleAnnouncementInfo>? value;
      super.onStart(R.current.getMoodleCourseAnnouncement);
      vv = await MoodleConnector.getCourseDirectory(id);
      if (vv != null) {
        String? url;
        for (var i in vv) {
          if (i.name.contains("一般") || i.name.contains("General")) {
            MoodleBranchJson? v = await MoodleConnector.getCourseBranch(i);
            if (v == null) {
              return await super
                  .onError(R.current.getMoodleCourseAnnouncementError);
            }
            for (var j in v.children) {
              if (j.name.contains("公佈欄")) {
                j.link += (LanguageUtils.getLangIndex() == LangEnum.zh)
                    ? "&lang=zh_tw"
                    : "&lang=en";
                url = j.link;
                break;
              }
            }
          }
          if (url != null) {
            break;
          }
        }
        value = (await MoodleConnector.getCourseAnnouncement(url!))!;
        super.onEnd();
        if (value != null) {
          result = value;
          return TaskStatus.Success;
        } else {
          return await super
              .onError(R.current.getMoodleCourseAnnouncementError);
        }
      } else {
        return await super.onError(R.current.getMoodleCourseAnnouncementError);
      }
    }
    return status;
  }
}
