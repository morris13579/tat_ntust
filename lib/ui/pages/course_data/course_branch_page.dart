import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/file/file_store.dart';
import 'package:flutter_app/src/file/my_downloader.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle/moodle_branch.dart';
import 'package:flutter_app/src/task/moodle/moodle_course_branch.dart';
import 'package:flutter_app/src/task/moodle/moodle_course_directory.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:get/get.dart';

class CourseBranchPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final MoodleCourseDirectoryInfo branch;

  CourseBranchPage(this.courseInfo, this.branch);

  @override
  _CourseBranchPageState createState() => _CourseBranchPageState();
}

class _CourseBranchPageState extends State<CourseBranchPage> {
  bool isLoading = true;
  MoodleBranchJson moodleBranch;

  @override
  void initState() {
    super.initState();
    loadbranch(widget.branch);
  }

  void loadbranch(MoodleCourseDirectoryInfo info) async {
    setState(() {
      isLoading = true;
    });
    TaskFlow taskFlow = TaskFlow();
    var task = MoodleCourseBranchTask(info);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      moodleBranch = task.result;
      if(moodleBranch.children.length == 0){
        MyToast.show(R.current.nothingHere);
        Get.back();
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.branch.name),
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
      itemCount: moodleBranch.children.length,
      itemBuilder: (BuildContext context, int index) {
        Children ap = moodleBranch.children[index];
        return InkWell(
          child: Container(
            height: 50,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  //https://moodle.ntust.edu.tw/theme/image.php/essential/forum/1624611875/${ap.icon.pix}
                  child: Icon((ap.link.contains("resource"))
                      ? Icons.file_copy_sharp
                      : Icons.folder_outlined),
                ),
                Expanded(
                  flex: 8,
                  child: Text(ap.name),
                ),
              ],
            ),
          ),
          onTap: () async {
            if (ap.link.contains("resource")) {
              await AnalyticsUtils.logDownloadFileEvent();
              MyToast.show(R.current.downloadWillStart);
              String dirName = widget.courseInfo.main.course.name;
              FileDownload.download(
                  context, ap.link + "&redirect=1", dirName, ap.name);
            } else {
              RouteUtils.toWebViewPage(ap.name, ap.link);
            }
          },
        );
      },
    );
  }
}
