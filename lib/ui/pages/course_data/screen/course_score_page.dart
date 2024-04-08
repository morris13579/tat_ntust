import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/ad/ad_manager.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/grade/table_data_type_a.dart';
import 'package:flutter_app/src/model/grade/table_data_type_b.dart';
import 'package:flutter_app/src/model/grade/tables.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_score.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_score_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class CourseScorePage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  const CourseScorePage(
    this.courseInfo, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseScorePageState();
}

class _CourseScorePageState extends State<CourseScorePage>
    with AutomaticKeepAliveClientMixin {
  Future<TablesEntity?> initTask() async {
    String courseId = widget.courseInfo.main.course.id;
    TaskFlow taskFlow = TaskFlow();
    var task = MoodleScoreTask(courseId);
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
      child: FutureBuilder<TablesEntity?>(
        future: initTask(),
        builder: (BuildContext context,
            AsyncSnapshot<TablesEntity?> snapshot) {
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
    );
  }

  Widget buildTree(TablesEntity scoreData) {
    return ListView.builder(itemBuilder: (context, index) {
      var data = scoreData.tableData[index];
      if(data.length <= 2) {
        // 標題
        var typeA = TableDataTypeAEntity.fromJson(data);
        // TODO: 加上UI
        return HtmlWidget("* ${typeA.itemName?.content ?? ""}");
      } else {
        // 成績內容
        var typeB = TableDataTypeBEntity.fromJson(data);
        // TODO: 加上UI
        return HtmlWidget(typeB.itemName?.content ?? "");
      }
    }, itemCount: scoreData.tableData.length,);
  }

  @override
  bool get wantKeepAlive => true;
}
