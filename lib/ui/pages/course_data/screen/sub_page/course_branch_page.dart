import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle/moodle_branch.dart';
import 'package:flutter_app/src/task/moodle/moodle_course_branch.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';

class CourseBranchPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final MoodleCourseDirectoryInfo branch;

  CourseBranchPage(this.courseInfo, this.branch);

  @override
  _CourseBranchPageState createState() => _CourseBranchPageState();
}

class _CourseBranchPageState extends State<CourseBranchPage> {
  bool isLoading = true;
  late MoodleBranchJson moodleBranch;

  @override
  void initState() {
    super.initState();
    loadBranch(widget.branch);
  }

  void loadBranch(MoodleCourseDirectoryInfo info) async {
    setState(() {
      isLoading = true;
    });
    TaskFlow taskFlow = TaskFlow();
    var task = MoodleCourseBranchTask(info);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      moodleBranch = task.result;
      if (moodleBranch.children.length == 0) {
        MyToast.show(R.current.nothingHere);
        Get.back();
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.branch.name),
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

  void handleTap(Children ap) async {
    switch (ap.icon.component) {
      case "forum":
        RouteUtils.toWebViewPage(ap.name, ap.link,
            openWithExternalWebView: false);
        break;
      case "assign":
        RouteUtils.toWebViewPage(ap.name, ap.link,
            openWithExternalWebView: false);
        break;
      case "folder":
        RouteUtils.toCourseFolderPage(widget.courseInfo, ap);
        break;
      case "label":
        break;
      case "url":
        RouteUtils.toWebViewPage(ap.name, ap.link + "&redirect=1",
            openWithExternalWebView: true);
        break;
      default:
        await AnalyticsUtils.logDownloadFileEvent();
        MyToast.show(R.current.downloadWillStart);
        String dirName = widget.courseInfo.main.course.name;
        FileDownload.download(
            context, ap.link + "&redirect=1", dirName, ap.name);
        break;
    }
  }

  final titleTextStyle = TextStyle(fontSize: 14);

  Widget buildItem(Children ap, int index) {
    switch (ap.icon.component) {
      case "label":
        return Container(
            padding: EdgeInsets.only(left: 20, top: 10, bottom: 10),
            child: SelectableHtml(data: ap.name));
      default:
        if (ap.contentAfterLink != null) {
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
                  child: SelectableHtml(data: ap.contentAfterLink)),
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
      itemCount: moodleBranch.children.length,
      itemBuilder: (BuildContext context, int index) {
        var ap = moodleBranch.children[index];
        return InkWell(
          child: Container(
            color: getColor(index),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  //https://moodle.ntust.edu.tw/theme/image.php/essential/forum/1624611875/${ap.icon.pix}
                  child: Icon(getIcon(ap.icon.component)),
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
