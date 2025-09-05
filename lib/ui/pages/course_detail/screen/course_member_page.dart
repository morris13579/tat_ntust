import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_member_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/components/page/loading_page.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class CourseMemberPage extends StatefulWidget {
  final String courseId;
  final SemesterJson semester;

  const CourseMemberPage(
    this.courseId,
    this.semester, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseMemberPageState();
}

class _CourseMemberPageState extends State<CourseMemberPage> with AutomaticKeepAliveClientMixin {
  final List<Widget> listItem = [];

  Future<List<MoodleCoreEnrolGetUsers>?> initTask() async {
    String courseId = widget.courseId;
    List<MoodleCoreEnrolGetUsers>? members;
    TaskFlow taskFlow = TaskFlow();
    var task = MoodleMemberTask(courseId, widget.semester);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      listItem.clear();
      members = task.result;
      listItem.add(_buildClassmateNumber(0, members.length));
      for (int i = 1; i < members.length; i++) {
        listItem.add(_buildClassmateInfo(i, members[i]));
      }
    }
    return task.result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); //如果使用AutomaticKeepAliveClientMixin需要呼叫
    return Container(
      padding: const EdgeInsets.only(top: 10),
      child: FutureBuilder<List<MoodleCoreEnrolGetUsers>?>(
        future: initTask(),
        builder: (BuildContext context,
            AsyncSnapshot<List<MoodleCoreEnrolGetUsers>?> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.data == null) {
              return const ErrorPage();
            } else {
              return getAnimationList();
            }
          } else if(snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingPage(isLoading: true, isShowBackground: false);
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
        itemBuilder: (BuildContext context, int index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: listItem[index],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClassmateNumber(int index, int number) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: UIUtils.getListColor(index),
      child: Text(
        "${S.current.totalMember} $number",
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildClassmateInfo(int index, MoodleCoreEnrolGetUsers member) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: UIUtils.getListColor(index),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
              child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(member.profileImageUrl),
                radius: 16,
              ),
              const SizedBox(width: 12),
              Text(
                member.studentId,
                textAlign: TextAlign.center,
              ),
            ],
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
