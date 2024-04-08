import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/task/course/course_extra_info_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:sprintf/sprintf.dart';

class CourseInfoPage extends StatefulWidget {
  final String courseId;
  final SemesterJson semester;

  const CourseInfoPage(
    this.courseId,
    this.semester, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseInfoPageState();
}

class _CourseInfoPageState extends State<CourseInfoPage>
    with AutomaticKeepAliveClientMixin {
  final List<Widget> courseData = [];
  final List<Widget?> listItem = [];

  Future<CourseExtraInfoJson?> initTask() async {
    CourseExtraInfoJson courseExtraInfo;
    String courseId = widget.courseId;
    TaskFlow taskFlow = TaskFlow();
    var task = CourseExtraInfoTask(courseId, widget.semester);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      listItem.clear();
      courseExtraInfo = task.result;

      listItem
          .add(_buildCourseInfo(R.current.semester, courseExtraInfo.semester));
      listItem
          .add(_buildCourseInfo(R.current.courseId, courseExtraInfo.courseNo));
      listItem.add(
          _buildCourseInfo(R.current.courseName, courseExtraInfo.courseName));
      listItem.add(_buildCourseInfo(
          R.current.instructor, courseExtraInfo.courseTeacher));
      listItem.add(_buildCourseInfo(
          "${R.current.courseTimes}/${R.current.practicalTimes}",
          sprintf("%s/%s",
              [courseExtraInfo.courseTimes, courseExtraInfo.practicalTimes])));
      listItem.add(_buildCourseInfo(
          R.current.requireOption,
          sprintf("%s/%s",
              [courseExtraInfo.requireOption, courseExtraInfo.allYear])));

      listItem.add(_buildCourseInfo(
          R.current.choosePeople,
          sprintf("%s ( %s / %s )", [
            courseExtraInfo.allStudent,
            courseExtraInfo.chooseStudent,
            courseExtraInfo.threeStudent
          ])));
      try {
        listItem.add(_buildCourseInfo(
            R.current.chooseUpBoundary,
            sprintf(R.current.choosePeopleString, [
              courseExtraInfo.restrict1,
              courseExtraInfo.restrict2,
              int.parse(courseExtraInfo.nTNURestrict) +
                  int.parse(courseExtraInfo.nTURestrict)
            ])));
      } catch (e) {
        Log.d(e.toString());
      }

      listItem.add(
          _buildCourseInfo(R.current.classRoomNo, courseExtraInfo.classRoomNo));
      listItem.add(
          _buildCourseInfo(R.current.coreAbility, courseExtraInfo.coreAbility));
      listItem.add(
          _buildCourseInfo(R.current.courseURL, courseExtraInfo.courseURL));
      listItem.add(_buildCourseInfo(
          R.current.courseObject, courseExtraInfo.courseObject));
      listItem.add(_buildCourseInfo(
          R.current.courseContent, courseExtraInfo.courseContent));
      listItem.add(_buildCourseInfo(
          R.current.courseTextbook, courseExtraInfo.courseTextbook));
      listItem.add(_buildCourseInfo(
          R.current.courseRefbook, courseExtraInfo.courseRefbook));
      listItem.add(
          _buildCourseInfo(R.current.courseNote, courseExtraInfo.courseNote));
      listItem.add(_buildCourseInfo(
          R.current.courseGrading, courseExtraInfo.courseGrading));
      listItem.add(_buildCourseInfo(
          R.current.courseRemark, courseExtraInfo.courseRemark));
    }
    return task.result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); //如果使用AutomaticKeepAliveClientMixin需要呼叫
    return Container(
      padding: const EdgeInsets.only(top: 10),
      child: FutureBuilder<CourseExtraInfoJson?>(
        future: initTask(),
        builder: (BuildContext context,
            AsyncSnapshot<CourseExtraInfoJson?> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.data == null) {
              return const ErrorPage();
            } else {
              return getAnimationList();
            }
          } else {
            return const Text("");
          }
        },
      ),
    );
  }

  Widget getAnimationList() {
    return AnimationLimiter(
      child: ListView.builder(
        itemCount: listItem.length,
        padding: const EdgeInsets.only(bottom: 6),
        itemBuilder: (BuildContext context, int index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: listItem[index] ?? const SizedBox(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget? _buildCourseInfo(String text, String info) {
    if (info.isEmpty) {
      return null;
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),),
            const SizedBox(height: 6),
            Text(info, style: const TextStyle(height: 1.2),),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
