import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/task/moodle/moodle_course_announcement_detail.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

class CourseAnnouncementDetailPage extends StatefulWidget {
  final MoodleAnnouncementInfo value;
  final CourseInfoJson courseInfo;

  CourseAnnouncementDetailPage(this.courseInfo, this.value);

  @override
  _CourseAnnouncementDetailPageState createState() =>
      _CourseAnnouncementDetailPageState();
}

class _CourseAnnouncementDetailPageState
    extends State<CourseAnnouncementDetailPage> {
  bool isLoading = true;
  String html;

  @override
  void initState() {
    super.initState();
    loadAnnouncementDetail(widget.value.url);
  }

  void loadAnnouncementDetail(String url) async {
    setState(() {
      isLoading = true;
    });
    TaskFlow taskFlow = TaskFlow();
    var task = MoodleCourseAnnouncementDetailTask(url);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      html = task.result;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.value.name),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Container(
              padding: EdgeInsets.only(right: 20, left: 20, top: 20),
              child: HtmlWidget(
                html,
                customStylesBuilder: (element) {
                  if (element.attributes.containsKey("href")) {
                    return {'color': '#3CB0FD'};
                  }
                  return null;
                },
                onTapUrl: (url) async {
                  if (Uri.parse(url).path.contains("pluginfile.php")) {
                    await AnalyticsUtils.logDownloadFileEvent();
                    MyToast.show(R.current.downloadWillStart);
                    String dirName = widget.courseInfo.main.course.name;
                    FileDownload.download(context, url, dirName);
                  } else {
                    RouteUtils.toWebViewPage(widget.value.name, url);
                  }
                },
              ),
            ),
    );
  }
}
