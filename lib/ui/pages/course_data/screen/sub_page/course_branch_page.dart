import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/task/moodle/moodle_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html_unescape/html_unescape.dart';

class CourseBranchPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final MoodleCoreCourseGetContents contents;

  CourseBranchPage(this.courseInfo, this.contents);

  @override
  _CourseBranchPageState createState() => _CourseBranchPageState();
}

class _CourseBranchPageState extends State<CourseBranchPage> {
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contents.name),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : buildTree(),
    );
  }

  IconData getIcon(String i) {
    switch (i) {
      case "forum":
        return Icons.message_outlined;
      case "folder":
        return Icons.folder_outlined;
      case "label":
        return Icons.label_outline;
      case "resource":
        return Icons.file_copy_outlined;
      default:
        return Icons.link;
    }
  }

  Widget buildTree() {
    final contents = widget.contents;
    return ListView.builder(
      shrinkWrap: true,
      itemCount: contents.modules.length,
      itemBuilder: (BuildContext context, int index) {
        var ap = contents.modules[index];
        return ap.modname.contains("label")
            ? Container(
                padding:
                    EdgeInsets.only(left: 10, right: 10, top: 15, bottom: 15),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Icon(getIcon(ap.modname)),
                    ),
                    Expanded(
                      flex: 8,
                      child: SelectableHtml(
                        data: ap.description,
                        onLinkTap: (url, context, attributes, element) {
                          RouteUtils.toWebViewPage(element.text, url,
                              openWithExternalWebView: false);
                        },
                      ),
                    ),
                  ],
                ),
              )
            : InkWell(
                child: Container(
                  padding:
                      EdgeInsets.only(left: 10, right: 10, top: 15, bottom: 15),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Icon(getIcon(ap.modname)),
                      ),
                      Expanded(
                          flex: 8,
                          child: Text(HtmlUnescape().convert(ap.name))),
                    ],
                  ),
                ),
                onTap: () async {
                  switch (ap.modname) {
                    case "forum":
                      if (Uri.parse(ap.url).host == "moodle.ntust.edu.tw") {
                        TaskFlow taskFlow = TaskFlow();
                        taskFlow.addTask(MoodleTask("WebView"));
                        await taskFlow.start();
                      }
                      RouteUtils.toWebViewPage(
                          ap.name,
                          Connector.uriAddQuery(
                            ap.url,
                            (LanguageUtils.getLangIndex() == LangEnum.zh)
                                ? {"lang": "zh_tw"}
                                : {"lang": "en"},
                          ),
                          openWithExternalWebView: false);
                      break;
                    case "folder":
                      if (ap.contents.length != 0) {
                        RouteUtils.toCourseFolderPage(widget.courseInfo, ap);
                      } else {
                        MyToast.show(R.current.nothingHere);
                      }
                      break;
                    case "label":
                      break;
                    case "resource":
                      await AnalyticsUtils.logDownloadFileEvent();
                      MyToast.show(R.current.downloadWillStart);
                      String dirName = widget.courseInfo.main.course.name;
                      FileDownload.download(
                          context,
                          Connector.uriAddQuery(
                            ap.contents.first.fileurl,
                            {"token": MoodleWebApiConnector.wsToken},
                          ),
                          dirName,
                          ap.contents.first.filename);
                      break;
                    default:
                      break;
                  }
                },
              );
      },
    );
  }
}
