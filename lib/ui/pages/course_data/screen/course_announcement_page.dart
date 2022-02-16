import 'package:flutter/material.dart';
import 'package:flutter_app/src/ad/ad_manager.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_course_message_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:intl/intl.dart';

class CourseAnnouncementPage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  CourseAnnouncementPage(this.courseInfo);

  @override
  _CourseAnnouncementPageState createState() => _CourseAnnouncementPageState();
}

class _CourseAnnouncementPageState extends State<CourseAnnouncementPage>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  late List<Discussions> discussions;

  @override
  void initState() {
    super.initState();
    String courseId = widget.courseInfo.main.course.id;
    loadAnnouncement(courseId);
  }

  void loadAnnouncement(String courseId) async {
    setState(() {
      isLoading = true;
    });
    TaskFlow taskFlow = TaskFlow();
    var task = MoodleCourseMessageTask(courseId);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      AdManager.showDownloadAD();
      discussions = task.result.discussions;
      setState(() {
        isLoading = false;
      });
    }
  }

  Color getColor(int index) {
    return (index % 2 == 1)
        ? Theme.of(context).backgroundColor
        : Theme.of(context).dividerColor;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); //如果使用AutomaticKeepAliveClientMixin需要呼叫
    return Scaffold(
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : buildTree(),
    );
  }

  Widget buildTree() {
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
            color: getColor(index),
            padding: EdgeInsets.only(top: 10, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Icon(Icons.message_outlined),
                ),
                Expanded(
                  flex: 9,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(ap.name)),
                          Expanded(
                            child: Text(
                              ap.userfullname,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatted,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
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
