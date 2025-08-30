import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_course_folder_detail_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/ui/pages/error/error_page.dart';

class CourseFolderPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final Modules modules;

  const CourseFolderPage(
    this.courseInfo,
    this.modules, {
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CourseFolderPageState();
}

class _CourseFolderPageState extends State<CourseFolderPage> {
  Future<Modules?> initTask() async {
    if (widget.modules.folderIsNone) {
      TaskFlow taskFlow = TaskFlow();
      var task = MoodleCourseFolderDetailTask(widget.modules);
      taskFlow.addTask(task);
      await taskFlow.start();
      return task.result;
    } else {
      return widget.modules;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.modules.name),
      ),
      body: Container(
        padding: const EdgeInsets.only(top: 10),
        child: FutureBuilder<Modules?>(
          future: initTask(),
          builder: (BuildContext context, AsyncSnapshot<Modules?> snapshot) {
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
      ),
    );
  }

  Color getColor(int index) {
    return (index % 2 == 1)
        ? Theme.of(context).scaffoldBackgroundColor
        : Theme.of(context).dividerColor;
  }

  Widget buildTree(Modules modules) {
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
