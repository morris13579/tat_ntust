import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/ad/ad_manager.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_score.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_score_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';

class CourseScorePage extends StatefulWidget {
  final CourseInfoJson courseInfo;

  const CourseScorePage(
    this.courseInfo, {
    Key? key,
  }) : super(key: key);

  @override
  _CourseScorePageState createState() => _CourseScorePageState();
}

class _CourseScorePageState extends State<CourseScorePage>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  late List<MoodleScoreItem> scoreList;

  @override
  void initState() {
    super.initState();
    String courseId = widget.courseInfo.main.course.id;
    loadScore(courseId);
  }

  void loadScore(String courseId) async {
    setState(() {
      isLoading = true;
    });
    TaskFlow taskFlow = TaskFlow();
    var task = MoodleScoreTask(courseId);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      AdManager.showDownloadAD();
      scoreList = task.result;
      setState(() {
        isLoading = false;
      });
    }
  }

  Color getColor(int index) {
    return (index % 2 == 1)
        ? Theme.of(context).backgroundColor
        : Theme.of(context).dividerColor;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); //如果使用AutomaticKeepAliveClientMixin需要呼叫
    return Scaffold(
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              child: buildTree(),
            ),
    );
  }

  Widget buildTree() {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 10),
      child: Table(
        columnWidths: const <int, TableColumnWidth>{
          //指定索引及固定列宽
          0: FixedColumnWidth(75.0),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        //設定表格樣式
        border: TableBorder.all(style: BorderStyle.solid),
        children: <TableRow>[
          TableRow(
            children: <Widget>[
              Text(R.current.rankItem),
              Text(R.current.weight),
              Text(R.current.score),
              Text(R.current.fullRange),
              Text(R.current.percentage),
              Text(R.current.feedback),
              Text(R.current.contribute),
            ],
          ),
          ...scoreList
              .map(
                (e) => TableRow(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.only(top: 5, bottom: 5),
                      child: Text(e.name),
                    ),
                    Text(e.weight),
                    Text(e.score),
                    Text(e.fullRange),
                    Text(e.percentage),
                    Text(e.feedback),
                    Text(e.contribute),
                  ],
                ),
              )
              .toList()
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
