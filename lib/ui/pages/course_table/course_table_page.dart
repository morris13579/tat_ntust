import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/course_config.dart';
import 'package:flutter_app/src/controller/course_table/course_controller.dart';
import 'package:flutter_app/src/enum/course_table_ui_state.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/ui/components/page/base_page.dart';
import 'package:flutter_app/ui/components/widget_size_render_object.dart';
import 'package:flutter_app/ui/pages/course_table/component/course_menu.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:screenshot/screenshot.dart';

import '../../components/over_repaint_boundary.dart';

class CourseTablePage extends GetView<CourseController> {
  const CourseTablePage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(CourseController());

    controller.refreshSemester();

    return Obx(() {
      return BasePage(
          title: R.current.titleCourse,
          resizeToAvoidBottomInset: false,
          isLoading: controller.isLoading.value == CourseTableUIState.loading,
          isError: controller.isLoading.value == CourseTableUIState.fail,
          action: actionList(),
          child: contentView());
    });
  }

  List<Widget> actionList() {
    return [
      IconButton(
        icon: SvgPicture.asset("assets/image/img_announcement.svg", color: Get.iconColor,),
        iconSize: 24,
        splashRadius: 18,
        onPressed: () {
          RemoteConfigUtils.showAnnouncementDialog(allTime: true);
        },
        enableFeedback: true,
      ),
      Visibility(
        visible: Model.instance.getAccount().isNotEmpty,
        child: IconButton(
          icon: const Icon(CupertinoIcons.refresh),
          splashRadius: 18,
          iconSize: 24,
          onPressed: () {
            controller.getCourseTable(
              semesterSetting: controller.semesterSetting.value,
              refresh: true,
            );
          },
          enableFeedback: true,
        ),
      ),
      Visibility(
        visible: Model.instance.getAccount().isNotEmpty,
        child: CourseMenu(
          studentId: controller.studentId.value,
          onSelected: controller.onPopupMenuSelect,
        ),
      )
    ];
  }

  Widget contentView() {
    return WidgetSizeOffsetWrapper(
      onSizeChange: (Size size) {
        controller.courseHeight.value = (size.height -
                CourseConfig.studentIdHeight -
                CourseConfig.dayHeight) /
            CourseConfig.showCourseTableNum; //計算每堂課高度
      },
      child: Column(
        key: controller.key,
        children: <Widget>[
          Container(
            height: CourseConfig.studentIdHeight,
            color: Get.theme.backgroundColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(controller.studentId.value),
                  ),
                ),
                TextButton(
                  onPressed: controller.showSemesterList,
                  child: Row(
                    children: <Widget>[
                      Text(
                        controller.semesterString.value,
                        textAlign: TextAlign.center,
                      ),
                      const Padding(
                        padding: EdgeInsets.all(5),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: controller.isLoading.value != CourseTableUIState.success
                ? const SizedBox()
                : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return SingleChildScrollView(
      child: Screenshot(
        controller: controller.screenshotController,
        child: Column(
          children: List.generate(
            controller.courseTableControl.getSectionIntList.length + 1,
                (index) {
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: ScaleAnimation(
                  child: FadeInAnimation(
                    child: (index == 0)
                        ? _buildDay()
                        : _buildCourseTable(index - 1),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildListViewWithScreenshot() {
    return SingleChildScrollView(
      child: OverRepaintBoundary(
        key: controller.overRepaintKey,
        child: RepaintBoundary(
          child: Column(
            children: List.generate(
              controller.courseTableControl.getSectionIntList.length + 1,
              (index) {
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: ScaleAnimation(
                    child: FadeInAnimation(
                      child: (index == 0)
                          ? _buildDay()
                          : _buildCourseTable(index - 1),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDay() {
    List<Widget> widgetList = [];
    widgetList.add(Container(
      width: CourseConfig.sectionWidth,
    ));
    for (int i in controller.courseTableControl.getDayIntList) {
      widgetList.add(
        Expanded(
          child: Text(
            controller.courseTableControl.getDayString(i),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Container(
      color: Get.theme.backgroundColor
          .withAlpha(CourseConfig.courseTableWithAlpha),
      height: CourseConfig.dayHeight,
      child: Row(
        children: widgetList,
      ),
    );
  }

  Widget _buildCourseTable(int index) {
    var courseTableControl = controller.courseTableControl;
    int section = courseTableControl.getSectionIntList[index];
    Color color;
    color =
        (index % 2 == 1) ? Get.theme.backgroundColor : Get.theme.dividerColor;
    color = color.withAlpha(CourseConfig.courseTableWithAlpha);
    List<Widget> widgetList = [];
    widgetList.add(
      Container(
        width: CourseConfig.sectionWidth,
        alignment: Alignment.center,
        child: Text(
          courseTableControl.getSectionString(section),
          textAlign: TextAlign.center,
        ),
      ),
    );
    for (int day in courseTableControl.getDayIntList) {
      CourseInfoJson? courseInfo =
          courseTableControl.getCourseInfo(day, section);
      Color color = courseTableControl.getCourseInfoColor(day, section);
      courseInfo = courseInfo ?? CourseInfoJson();
      widgetList.add(
        Expanded(
          child: (courseInfo.isEmpty)
              ? const SizedBox()
              : Container(
                  padding: const EdgeInsets.all(1),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(0),
                      backgroundColor: color,
                    ),
                    child: AutoSizeText(
                      courseInfo.main.course.name,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      minFontSize: 10,
                      maxLines: 3,
                      textAlign: TextAlign.center,
                    ),
                    onPressed: () {
                      controller.showCourseDetailDialog(section, courseInfo!);
                    },
                  ),
                ),
        ),
      );
    }
    return Container(
      color: color,
      height: controller.courseHeight.value,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widgetList,
      ),
    );
  }
}
