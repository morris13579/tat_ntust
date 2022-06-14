import 'dart:async';

import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_member_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

class CourseMemberPage extends StatefulWidget {
  final String courseId;

  const CourseMemberPage(
    this.courseId, {
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CourseMemberPageState();
}

class _CourseMemberPageState extends State<CourseMemberPage>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  final List<Widget> listItem = [];
  bool canPop = true;

  @override
  void initState() {
    super.initState();
    isLoading = true;
    BackButtonInterceptor.add(myInterceptor);
    Future.delayed(Duration.zero, () {
      _addTask();
    });
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(myInterceptor);
    super.dispose();
  }

  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo routeInfo) {
    if (!canPop) {
      Get.back();
    }
    return !canPop;
  }

  void _addTask() async {
    String courseId = widget.courseId;
    TaskFlow taskFlow = TaskFlow();
    var task = MoodleMemberTask(courseId);
    taskFlow.addTask(task);
    late List<MoodleCoreEnrolGetUsers> members;
    if (await taskFlow.start()) {
      members = task.result;
      listItem.add(_buildClassmateNumber(0, members.length));
      for (int i = 1; i < members.length; i++) {
        listItem.add(_buildClassmateInfo(i, members[i]));
      }
      isLoading = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); //如果使用AutomaticKeepAliveClientMixin需要呼叫
    return Container(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: <Widget>[
          (isLoading)
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Expanded(
                  child: getAnimationList(),
                ),
        ],
      ),
    );
  }

  Widget getAnimationList() {
    return AnimationLimiter(
      child: ListView.builder(
        itemCount: listItem.length,
        itemBuilder: (BuildContext context, int index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, //讓透明部分有反應
                  child: Container(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: listItem[index]),
                  onTap: () {},
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClassmateNumber(int index, int number) {
    Color color;
    color = (index % 2 == 1)
        ? Theme.of(context).backgroundColor
        : Theme.of(context).dividerColor;
    return Container(
      padding: const EdgeInsets.all(5),
      color: color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              "${S.current.totalMember} $number",
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassmateInfo(int index, MoodleCoreEnrolGetUsers member) {
    Color color;
    color = (index % 2 == 1)
        ? Theme.of(context).backgroundColor
        : Theme.of(context).dividerColor;
    return Container(
      padding: const EdgeInsets.all(5),
      color: color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
              child: Text(
            member.studentId,
            textAlign: TextAlign.center,
          )),
          Expanded(
            child: Text(
              member.name,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
