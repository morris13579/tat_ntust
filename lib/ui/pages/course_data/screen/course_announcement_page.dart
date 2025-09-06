import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/ad/ad_manager.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_course_message_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class CourseAnnouncementPage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  const CourseAnnouncementPage(
    this.courseInfo, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseAnnouncementPageState();
}

class _CourseAnnouncementPageState extends State<CourseAnnouncementPage>
    with AutomaticKeepAliveClientMixin {
  Future<List<Discussions>?> initTask() async {
    String courseId = widget.courseInfo.main.course.id;
    TaskFlow taskFlow = TaskFlow();
    var task = MoodleCourseMessageTask(courseId);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      AdManager.showDownloadAD();
    }
    return task.result.discussions;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); //如果使用AutomaticKeepAliveClientMixin需要呼叫
    return Container(
      padding: const EdgeInsets.only(top: 10),
      child: FutureBuilder<List<Discussions>?>(
        future: initTask(),
        builder:
            (BuildContext context, AsyncSnapshot<List<Discussions>?> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.data == null) {
              return const ErrorPage();
            } else {
              return buildTree(snapshot.data!);
            }
          } else {
            return const Text("");
          }
        },
      ),
    );
  }

  Widget buildTree(List<Discussions> discussions) {
    if (discussions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset("assets/image/img_open_folder.svg",
                color: Get.theme.colorScheme.onSurface, height: 72),
            const SizedBox(height: 24),
            Text(R.current.announcementEmpty)
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: discussions.length,
      itemBuilder: (BuildContext context, int index) {
        var ap = discussions[index];
        final DateFormat formatter = DateFormat.yMd().add_jm();

        final String formatted = formatter
            .format(DateTime.fromMillisecondsSinceEpoch(ap.modified * 1000));

        return InkWell(
          child: Container(
            color: UIUtils.getListColor(index),
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: SvgPicture.asset(
                    "assets/image/img_message.svg",
                    color: Get.theme.colorScheme.onSurface,
                  ),
                ),
                Expanded(
                    child: Text(
                  ap.name,
                  style: TextStyle(
                      height: 1.2,
                      color: Get.theme.colorScheme.onSurface,
                      overflow: TextOverflow.fade),
                  maxLines: 2,
                )),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ap.userfullname,
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatted,
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          onTap: () async {
            RouteUtils.toAnnouncementDetailPage(widget.courseInfo, ap);
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
