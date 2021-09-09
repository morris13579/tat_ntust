import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/task/moodle/moodle_course_announcement.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';

class CourseAnnouncementPage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  CourseAnnouncementPage(this.courseInfo);

  @override
  _CourseAnnouncementPageState createState() => _CourseAnnouncementPageState();
}

class _CourseAnnouncementPageState extends State<CourseAnnouncementPage>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  List<MoodleAnnouncementInfo> announcementList;

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
    var task = MoodleCourseAnnouncementTask(courseId);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      announcementList = task.result;
      setState(() {
        isLoading = false;
      });
    }
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
      itemCount: announcementList.length,
      itemBuilder: (BuildContext context, int index) {
        MoodleAnnouncementInfo ap = announcementList[index];
        return InkWell(
          child: Container(
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
                              ap.author,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ap.time,
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
