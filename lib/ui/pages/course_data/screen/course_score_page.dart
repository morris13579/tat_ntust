import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/ad/ad_manager.dart';
import 'package:flutter_app/src/config/app_colors.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/grade/table_data_type_a.dart';
import 'package:flutter_app/src/model/grade/table_data_type_b.dart';
import 'package:flutter_app/src/model/grade/tables.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_score_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_app/ui/pages/photo_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';

import '../../../../src/R.dart';

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
        builder: (BuildContext context, AsyncSnapshot<TablesEntity?> snapshot) {
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
    return ListView.builder(
      itemBuilder: (context, index) {
        var data = scoreData.tableData[index];
        if (data.length == 2) {
          var typeA = TableDataTypeAEntity.fromJson(data);
          // 第一個為課程名字
          if (index == 0) {
            return const SizedBox();
          }
          // 標題
          return Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 2),
            child: Row(
              children: [
                SvgPicture.asset("assets/image/img_folder.svg",
                    color: Get.iconColor, height: 22),
                const SizedBox(width: 4),
                HtmlWidget(
                  typeA.itemName?.content ?? "",
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        } else if (data.length == 7) {
          // 成績內容
          var typeB = TableDataTypeBEntity.fromJson(data);
          var itemName = typeB.itemName;
          if (itemName == null) {
            return const SizedBox();
          }
          var isInFolder = !itemName.class_.contains("level2") &&
              !itemName.class_.contains("level1");

          return ExpansionTile(
            title: HtmlWidget(typeB.itemName?.content ?? "",
                textStyle: const TextStyle(height: 1.2),
                customStylesBuilder: (element) {
              if (element.localName == 'a') {
                String colorString = AppColors.mainColor.toString();
                String urlColor =
                    '#${colorString.split('(0xff')[1].split(')')[0]}';
                return {'color': urlColor};
              }
              return null;
            }),
            tilePadding: EdgeInsets.only(left: isInFolder ? 18 : 0),
            dense: true,
            clipBehavior: Clip.antiAlias,
            trailing: const Icon(
              CupertinoIcons.chevron_down,
              size: 12,
            ),
            expandedAlignment: Alignment.centerLeft,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            childrenPadding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _gradeItem(R.current.weight, typeB.weight.content),
              Visibility(
                visible: typeB.percentage.content.isNotEmpty,
                child:
                    _gradeItem(R.current.percentage, typeB.percentage.content),
              ),
              _gradeItem(R.current.fullRange, typeB.range.content),
              Visibility(
                visible: typeB.feedback.content.isNotEmpty,
                child: _gradeItem(R.current.feedback, typeB.feedback.content),
              ),
              Visibility(
                visible: typeB.percentage.content.isNotEmpty,
                child:
                    _gradeItem(R.current.percentage, typeB.percentage.content),
              ),
              _gradeItem(R.current.contributionCourse,
                  typeB.contributionToCourseTotal.content),
            ],
          );
        } else {
          return Divider(color: Get.iconColor);
        }
      },
      itemCount: scoreData.tableData.length,
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _gradeItem(String title, String content) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        HtmlWidget(content ?? "-", textStyle: Get.textTheme.bodyMedium,
            customWidgetBuilder: (element) {
          if (element.localName == 'img') {
            var url = element.attributes["src"] ?? "";
            return FutureBuilder<Uint8List?>(
              future: DioConnector.instance.getData(ConnectorParameter(url)),
              builder: (context, snapshot) {
                if(snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: GestureDetector(onTap: () {
                      Get.to(PhotoView(imageData:snapshot.data!));
                    }, child: Image.memory(snapshot.data!)),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LoadingPage(isLoading: true, isShowBackground: false,),
                );
              }
            );
          }
          return null;
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
