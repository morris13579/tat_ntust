import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle/moodle_branch.dart';
import 'package:flutter_app/src/task/moodle/moodle_course_folder.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:get/get.dart';

class CourseFolderPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final Children children;

  CourseFolderPage(this.courseInfo, this.children);

  @override
  _CourseFolderPageState createState() => _CourseFolderPageState();
}

class _CourseFolderPageState extends State<CourseFolderPage> {
  bool isLoading = true;
  List<MoodleFileInfo> item = [];

  @override
  void initState() {
    super.initState();
    loadFolder(widget.children.link);
  }

  void loadFolder(String url) async {
    setState(() {
      isLoading = true;
    });
    TaskFlow taskFlow = TaskFlow();
    MoodleCourseFolderTask task = MoodleCourseFolderTask(url);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      item = task.result;
      if (item.length == 0) {
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
        title: Text(widget.children.name),
      ),
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
      itemCount: item.length,
      itemBuilder: (BuildContext context, int index) {
        MoodleFileInfo ap = item[index];
        return InkWell(
          child: Container(
            height: 50,
            color: getColor(index),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  //https://moodle.ntust.edu.tw/theme/image.php/essential/forum/1624611875/${ap.icon.pix}
                  child: Icon(Icons.file_copy),
                ),
                Expanded(
                  flex: 8,
                  child: Text(ap.name),
                ),
              ],
            ),
          ),
          onTap: () async {
            String dirName = widget.courseInfo.main.course.name;
            FileDownload.download(context, ap.url, dirName, name: ap.name);
          },
        );
      },
    );
  }
}
