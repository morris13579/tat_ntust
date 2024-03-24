import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/ad/ad_manager.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_course_directory_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/components/tile/course_info_tile.dart';
import 'package:flutter_app/ui/other/my_toast.dart';

class CourseDirectoryPage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  const CourseDirectoryPage(
    this.courseInfo, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseDirectoryPageState();
}

class _CourseDirectoryPageState extends State<CourseDirectoryPage>
    with AutomaticKeepAliveClientMixin {
  Future<List<MoodleCoreCourseGetContents>?> initTask() async {
    String courseId = widget.courseInfo.main.course.id;
    TaskFlow taskFlow = TaskFlow();
    var task = MoodleCourseDirectoryTask(courseId);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      AdManager.showDownloadAD();
    }
    return task.result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); //如果使用AutomaticKeepAliveClientMixin需要呼叫
    return Container(
      padding: const EdgeInsets.only(top: 10),
      child: FutureBuilder<List<MoodleCoreCourseGetContents>?>(
        future: initTask(),
        builder: (BuildContext context,
            AsyncSnapshot<List<MoodleCoreCourseGetContents>?> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.data == null) {
              return const ErrorPage();
            } else {
              return buildTree(snapshot.data!);
            }
          } else {
            return const SizedBox();
          }
        },
      ),
    );
  }

  Widget buildTree(List<MoodleCoreCourseGetContents> directoryList) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: directoryList.length,
      itemBuilder: (BuildContext context, int index) {
        var ap = directoryList[index];
        return CourseInfoTile(
            index: index,
            title: ap.name,
            img: "img_file",
            isShowArrow: ap.modules.isNotEmpty,
            onTap: () {
              if (ap.modules.isEmpty) {
                MyToast.show(R.current.nothingHere);
                return;
              }
              RouteUtils.toCourseInfoPage(widget.courseInfo, ap);
            });
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
