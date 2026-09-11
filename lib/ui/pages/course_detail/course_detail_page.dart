import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/controller/course_detail/course_detail_controller.dart';
import 'package:flutter_app/src/controller/course_member/course_member_controller.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/open_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/pages/course_detail/screen/course_info_page.dart';
import 'package:flutter_app/ui/pages/course_member/course_member_page.dart';

class CourseDetailPage extends StatefulWidget {
  final CourseInfoJson courseInfo;
  final SemesterJson semester;

  const CourseDetailPage(
    this.courseInfo,
    this.semester, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  late final CourseDetailController _controller;

  /// 名單的 controller 住在這一頁而不是名單頁：名單頁 pop 掉之後它還活著，
  /// 返回再進去就直接畫上一次的結果，不會再等一次那支慢的 API。
  late final CourseMemberController _memberController;

  @override
  void initState() {
    super.initState();
    final courseId = widget.courseInfo.main.course.id;
    _controller = CourseDetailController(
      courseId: courseId,
      semester: widget.semester,
    );
    _memberController = CourseMemberController(courseId: courseId);
    // 只抓課程資訊。名單那支很慢，等真的有人要看名單再打。
    unawaited(_controller.loadInfo());
  }

  @override
  void dispose() {
    _controller.dispose();
    _memberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(title: widget.courseInfo.main.course.name),
      body: CourseInfoPage(
        controller: _controller,
        errorBuilder: (message) =>
            InlineErrorView(message: message, onRetry: _controller.loadInfo),
        onOpenMembers: _openMembers,
        onOpenUrl: (url) => unawaited(OpenUtils.launchURL(url)),
      ),
    );
  }

  void _openMembers(int knownMemberCount) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseMemberPage(
          controller: _memberController,
          courseName: widget.courseInfo.main.course.name,
          knownMemberCount: knownMemberCount,
          errorBuilder: (message, onRetry) =>
              InlineErrorView(message: message, onRetry: onRetry),
        ),
      ),
    );
  }
}
