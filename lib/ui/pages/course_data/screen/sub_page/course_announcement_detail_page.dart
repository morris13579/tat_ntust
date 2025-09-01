import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_course_message_detail_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/components/tile/course_info_tile.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html_unescape/html_unescape.dart';

class CourseAnnouncementDetailPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final Discussions discussions;

  const CourseAnnouncementDetailPage(
    this.courseInfo,
    this.discussions, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseAnnouncementDetailPageState();
}

class _CourseAnnouncementDetailPageState
    extends State<CourseAnnouncementDetailPage> {
  late String html;

  Future<Discussions?> initTask() async {
    if (widget.discussions.isNone) {
      TaskFlow taskFlow = TaskFlow();
      var task = MoodleCourseMessageDetailTask(widget.discussions);
      taskFlow.addTask(task);
      await taskFlow.start();
      return task.result;
    } else {
      return widget.discussions;
    }
  }

  Future<bool> onLinkTap(Discussions discussions, String url) async {
    if (Uri.parse(url).path.contains("pluginfile.php")) {
      String dirName = widget.courseInfo.main.course.name;
      FileDownload.download(context, url, dirName);
    } else {
      RouteUtils.toWebViewPage(discussions.name, url);
    }
    return true;
  }

  Color getColor(int index) {
    return (index % 2 == 1)
        ? Theme.of(context).scaffoldBackgroundColor
        : Theme.of(context).dividerColor;
  }

  @override
  Widget build(BuildContext context) {
    Discussions discussions = widget.discussions;
    html = discussions.message;
    return Scaffold(
      appBar: baseAppbar(
        title: HtmlUnescape().convert(discussions.name)
      ),
      body: Container(
        padding: const EdgeInsets.only(top: 10),
        child: FutureBuilder<Discussions?>(
          future: initTask(),
          builder:
              (BuildContext context, AsyncSnapshot<Discussions?> snapshot) {
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

  Widget buildTree(Discussions discussions) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(right: 20, left: 20, top: 20),
          child: HtmlWidget(
            html,
            renderMode: RenderMode.column,
            textStyle: const TextStyle(height: 1.2),
            onTapUrl: (String s) => onLinkTap(discussions, s),
          ),
        ),
        Container(
          height: 20,
        ),
        ListView.builder(
          shrinkWrap: true,
          itemCount: discussions.attachments.length,
          itemBuilder: (BuildContext context, int index) {
            var ap = discussions.attachments[index];
            return CourseInfoTile(index: index, title: ap.filename, img: "img_doc", onTap: () {
              String dirName = widget.courseInfo.main.course.name;
              FileDownload.download(
                  context,
                  Connector.uriAddQuery(
                    ap.fileurl,
                    {"token": MoodleWebApiConnector.wsToken},
                  ),
                  dirName,
                  name: ap.filename);
            });
          },
        )
      ],
    );
  }
}
