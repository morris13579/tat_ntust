import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/file/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';

class CourseFolderWebApiPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final Modules modules;

  CourseFolderWebApiPage(this.courseInfo, this.modules);

  @override
  _CourseFolderWebApiPageState createState() => _CourseFolderWebApiPageState();
}

class _CourseFolderWebApiPageState extends State<CourseFolderWebApiPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.modules.name),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : buildTree(),
    );
  }

  Widget buildTree() {
    Modules modules = widget.modules;
    return ListView.builder(
      shrinkWrap: true,
      itemCount: modules.contents.length,
      itemBuilder: (BuildContext context, int index) {
        var ap = modules.contents[index];
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
                context,
                Connector.uriAddQuery(
                  ap.fileurl,
                  {"token": MoodleWebApiConnector.wsToken},
                ),
                dirName,
                ap.filename);
          },
        );
      },
    );
  }
}
