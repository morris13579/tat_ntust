import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class CourseInfoPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final MoodleCoreCourseGetContents contents;

  CourseInfoPage(this.courseInfo, this.contents);

  @override
  _CourseInfoPageState createState() => _CourseInfoPageState();
}

class _CourseInfoPageState extends State<CourseInfoPage> {
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

  IconData getIcon(String type) {
    switch (type) {
      case "forum":
        return Icons.message_outlined;
      case "assign":
        return Icons.assignment_outlined;
      case "folder":
        return Icons.folder_outlined;
      case "label":
        return Icons.label_outline;
      case "url":
        return Icons.link_outlined;
      default:
        return Icons.file_copy_outlined;
    }
  }

  void openWebView(Modules ap, {openWithExternalWebView = false}) async {
    RouteUtils.toWebViewPage(
        ap.name,
        Connector.uriAddQuery(
          ap.url,
          (LanguageUtils.getLangIndex() == LangEnum.zh)
              ? {"lang": "zh_tw"}
              : {"lang": "en"},
        ),
        openWithExternalWebView: openWithExternalWebView);
  }

  void handleTap(Modules ap) async {
    switch (ap.modname) {
      case "forum":
        openWebView(ap);
        break;
      case "assign":
        openWebView(ap);
        break;
      case "folder":
        if (ap.contents.length != 0 || ap.folderIsNone) {
          RouteUtils.toCourseFolderPage(widget.courseInfo, ap);
        } else {
          MyToast.show(R.current.nothingHere);
        }
        break;
      case "label":
        break;
      case "url":
        openWebView(ap, openWithExternalWebView: true);
        break;
      case "resource":
      default:
        String dirName = widget.courseInfo.main.course.name;
        FileDownload.download(
            context,
            Connector.uriAddQuery(
              ap.contents.first.fileurl,
              {"token": MoodleWebApiConnector.wsToken},
            ),
            dirName,
            name: ap.contents.first.filename);
    }
  }

  final titleTextStyle = TextStyle(fontSize: 14);

  Widget buildItem(Modules ap, int index) {
    switch (ap.modname) {
      case "label":
        return Container(
            padding: EdgeInsets.only(left: 20, top: 10, bottom: 10),
            child: HtmlWidget(
              ap.description,
              isSelectable: true,
            ));
      default:
        if (ap.description.isNotEmpty) {
          return ExpansionTileCard(
            expandedTextColor: Theme.of(context).textTheme.bodyText1!.color,
            expandedColor: getColor(index),
            baseColor: getColor(index),
            title: Text(
              ap.name,
              style: titleTextStyle,
            ),
            children: [
              Container(
                padding: EdgeInsets.only(left: 20),
                child: HtmlWidget(
                  ap.description,
                  isSelectable: true,
                ),
              ),
              Container(
                height: 50,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        child: Icon(Icons.download_outlined),
                        onTap: () {
                          handleTap(ap);
                        },
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        }
        return Container(
          height: 50,
          padding: EdgeInsets.only(left: 20),
          child: Row(
            children: [
              Text(
                ap.name,
                style: titleTextStyle,
              )
            ],
          ),
        );
    }
  }

  Color getColor(int index) {
    return (index % 2 == 1)
        ? Theme.of(context).backgroundColor
        : Theme.of(context).dividerColor;
  }

  Widget buildTree() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.contents.modules.length,
      itemBuilder: (BuildContext context, int index) {
        var ap = widget.contents.modules[index];
        return InkWell(
          child: Container(
            color: getColor(index),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  //https://moodle.ntust.edu.tw/theme/image.php/essential/forum/1624611875/${ap.icon.pix}
                  child: Icon(getIcon(ap.modname)),
                ),
                Expanded(
                  flex: 8,
                  child: buildItem(ap, index),
                ),
              ],
            ),
          ),
          onTap: () async {
            handleTap(ap);
          },
        );
      },
    );
  }
}
