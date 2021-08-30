import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle/moodle_branch.dart';
import 'package:flutter_app/src/task/moodle/moodle_course_directory.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';

class CourseDataPage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  CourseDataPage(this.courseInfo);

  @override
  _CourseDataPageState createState() => _CourseDataPageState();
}

class _CourseDataPageState extends State<CourseDataPage> {
  bool isLoading = true;
  List<MoodleCourseDirectoryInfo> directoryList;

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
      directoryList = task.result;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseInfo.main.course.name),
      ),
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
      itemCount: directoryList.length,
      itemBuilder: (BuildContext context, int index) {
        MoodleCourseDirectoryInfo ap = directoryList[index];
        return InkWell(
          child: Container(
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
}
