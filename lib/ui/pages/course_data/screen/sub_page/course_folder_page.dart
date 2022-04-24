import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_course_folder_detail_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';

class CourseFolderPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final Modules modules;

  const CourseFolderPage(
    this.courseInfo,
    this.modules, {
    Key? key,
  }) : super(key: key);

  @override
  _CourseFolderPageState createState() => _CourseFolderPageState();
}

class _CourseFolderPageState extends State<CourseFolderPage> {
  bool isLoading = true;
  late Modules modules;

  @override
  void initState() {
    super.initState();
    initDetail();
  }

  void initDetail() async {
    if (widget.modules.folderIsNone) {
      setState(() {
        isLoading = true;
      });
      TaskFlow taskFlow = TaskFlow();
      var task = MoodleCourseFolderDetailTask(widget.modules);
      taskFlow.addTask(task);
      if (await taskFlow.start()) {
        modules = task.result;
      }
      setState(() {
        isLoading = false;
      });
    } else {
      modules = widget.modules;
      isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.modules.name),
      ),
      body: isLoading
          ? const Center(
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
      itemCount: modules.contents.length,
      itemBuilder: (BuildContext context, int index) {
        var ap = modules.contents[index];
        return InkWell(
          child: Container(
            color: getColor(index),
            height: 50,
            child: Row(
              children: [
                const Expanded(
                  flex: 1,
                  child: Icon(Icons.file_copy),
                ),
                Expanded(
                  flex: 8,
                  child: Text(ap.filename),
                ),
              ],
            ),
          ),
          onTap: () async {
            String dirName = widget.courseInfo.main.course.name;
            FileDownload.download(
                context,
                Connector.uriAddQuery(
                  ap.fileurl,
                  {"token": MoodleWebApiConnector.wsToken},
                ),
                dirName,
                name: ap.filename);
          },
        );
      },
    );
  }
}
