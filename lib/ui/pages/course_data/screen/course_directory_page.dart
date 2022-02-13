import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/ad/ad_manager.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_course_directory_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';

class CourseDirectoryPage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  CourseDirectoryPage(this.courseInfo);

  @override
  _CourseDirectoryPageState createState() => _CourseDirectoryPageState();
}

class _CourseDirectoryPageState extends State<CourseDirectoryPage>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  late List<MoodleCoreCourseGetContents> directoryList;

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
      itemCount: directoryList.length,
      itemBuilder: (BuildContext context, int index) {
        var ap = directoryList[index];
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
                if (ap.modules.length != 0)
                  Icon(Icons.arrow_forward_ios_rounded, size: 16)
              ],
            ),
          ),
          onTap: () async {
            if (ap.modules.length != 0) {
              RouteUtils.toCourseInfoPage(widget.courseInfo, ap);
            } else {
              MyToast.show(R.current.nothingHere);
            }
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
