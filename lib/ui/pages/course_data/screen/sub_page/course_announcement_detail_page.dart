import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_html/flutter_html.dart';
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
  String html;
  bool selectAble = false;

  @override
  void initState() {
    super.initState();
    isLoading = false;
  }

  onLinkTap(url, renderContext, attributes, element) async {
    if (Uri.parse(url).path.contains("pluginfile.php")) {
      await AnalyticsUtils.logDownloadFileEvent();
      MyToast.show(R.current.downloadWillStart);
      String dirName = widget.courseInfo.main.course.name;
      FileDownload.download(context, url, dirName, element.text);
    } else {
      RouteUtils.toWebViewPage(widget.discussions.name, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    Discussions discussions = widget.discussions;
    html = discussions.message;
    return Scaffold(
      appBar: AppBar(
        title: Text(HtmlUnescape().convert(discussions.name)),
        actions: [
          IconButton(
            icon: Icon(
                (selectAble) ? Icons.lock_open_outlined : Icons.lock_outline),
            onPressed: () {
              setState(() {
                selectAble = !selectAble;
              });
            },
            tooltip: R.current.selectAble,
          )
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Container(
                  padding: EdgeInsets.only(right: 20, left: 20, top: 20),
                  child: (selectAble)
                      ? SelectableHtml(data: html, onLinkTap: onLinkTap)
                      : Html(data: html, onLinkTap: onLinkTap),
                ),
                if(discussions.attachments != null)
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: discussions.attachments.length,
                  itemBuilder: (BuildContext context, int index) {
                    var ap = discussions.attachments[index];
                    return InkWell(
                      child: Container(
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
                        await AnalyticsUtils.logDownloadFileEvent();
                        MyToast.show(R.current.downloadWillStart);
                        String dirName = widget.courseInfo.main.course.name;
                        FileDownload.download(
                            context, ap.fileurl, dirName, ap.filename);
                      },
                    );
                  },
                )
              ],
            ),
    );
  }
}
