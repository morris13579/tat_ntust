import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_course_message_detail_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html_unescape/html_unescape.dart';

class CourseAnnouncementDetailPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final Discussions discussions;

  CourseAnnouncementDetailPage(this.courseInfo, this.discussions);

  @override
  _CourseAnnouncementDetailPageState createState() =>
      _CourseAnnouncementDetailPageState();
}

class _CourseAnnouncementDetailPageState
    extends State<CourseAnnouncementDetailPage> {
  bool isLoading = true;
  late String html;
  late Discussions discussion;
  @override
  void initState() {
    super.initState();
    initDetail();
  }

  void initDetail() async {
    if (widget.discussions.isNone) {
      setState(() {
        isLoading = true;
      });
      TaskFlow taskFlow = TaskFlow();
      var task = MoodleCourseMessageDetailTask(widget.discussions);
      taskFlow.addTask(task);
      if (await taskFlow.start()) {
        discussion = task.result;
      }
      setState(() {
        isLoading = false;
      });
    } else {
      isLoading = false;
    }
  }

  Future<bool> onLinkTap(url) async {
    if (Uri.parse(url).path.contains("pluginfile.php")) {
      String dirName = widget.courseInfo.main.course.name;
      FileDownload.download(context, url, dirName);
    } else {
      RouteUtils.toWebViewPage(discussion.name, url);
    }
    return true;
  }

  Color getColor(int index) {
    return (index % 2 == 1)
        ? Theme.of(context).backgroundColor
        : Theme.of(context).dividerColor;
  }

  @override
  Widget build(BuildContext context) {
    Discussions discussions = widget.discussions;
    html = discussions.message;
    return Scaffold(
      appBar: AppBar(
        title: Text(HtmlUnescape().convert(discussions.name)),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Container(
                  padding: EdgeInsets.only(right: 20, left: 20, top: 20),
                  child: HtmlWidget(
                    html,
                    isSelectable: true,
                    onTapUrl: onLinkTap,
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: discussions.attachments.length,
                  itemBuilder: (BuildContext context, int index) {
                    var ap = discussions.attachments[index];
                    return InkWell(
                      child: Container(
                        color: getColor(index),
                        height: 50,
                        child: Row(
                          children: [
                            Expanded(
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
                )
              ],
            ),
    );
  }
}
