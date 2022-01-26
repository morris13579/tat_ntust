import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/ad/ad_manager.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/task/moodle/moodle_course_directory_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';

class CourseDirectoryPage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  CourseDirectoryPage(this.courseInfo);

  @override
  _CourseDirectoryPageState createState() => _CourseDirectoryPageState();
}

class _CourseDirectoryPageState extends State<CourseDirectoryPage>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  late List<MoodleCourseDirectoryInfo> directoryList;

  @override
  void initState() {
    super.initState();
    String courseId = widget.courseInfo.main.course.id;
    loadDirectory(courseId);
  }

  void loadDirectory(String courseId) async {
    setState(() {
      isLoading = true;
    });
    TaskFlow taskFlow = TaskFlow();
    var task = MoodleCourseDirectoryTask(courseId);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      AdManager.showDownloadAD();
      directoryList = task.result;
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

  Color getColor(int index) {
    return (index % 2 == 1)
        ? Theme.of(context).backgroundColor
        : Theme.of(context).dividerColor;
  }

  Widget buildTree() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: directoryList.length,
      itemBuilder: (BuildContext context, int index) {
        MoodleCourseDirectoryInfo ap = directoryList[index];
        return InkWell(
          child: Container(
            color: getColor(index),
            height: 50,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Icon(Icons.folder_outlined),
                ),
                Expanded(
                  flex: 8,
                  child: Text(ap.name),
                ),
                if (ap.expandAble) Icon(Icons.expand_more)
              ],
            ),
          ),
          onTap: () async {
            RouteUtils.toCourseBranchPage(widget.courseInfo, ap);
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
