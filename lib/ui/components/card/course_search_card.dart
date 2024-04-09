import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../src/R.dart';

class CourseSearchCard extends StatelessWidget {
  const CourseSearchCard({super.key, required this.info, required this.onTap});

  final CourseMainInfoJson info;
  final Function(CourseMainInfoJson) onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => onTap(info),
      child: DefaultTextStyle(
        style: Get.textTheme.bodyMedium!,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.course.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(info.course.id, style: const TextStyle(fontSize: 14, color: Colors.grey),),
              const SizedBox(height: 2),
              teacherText(),
              const SizedBox(height: 2),
              timeText(),
              const SizedBox(height: 2),
              Text("${R.current.startClass}: ${info.getOpenClassName().isEmpty ? "--" : info.getOpenClassName()}"),
              const SizedBox(height: 2),
              Text("${R.current.classroom}: ${info.getClassroomName()}"),
              const SizedBox(height: 2),
              Text("${R.current.note}: ${info.course.note}"),
            ],
          ),
        ),
      ),
    );
  }

  Widget timeText() {
    return _iconWithText("img_clock.svg", info.getTime());
  }

  Widget teacherText() {
    return _iconWithText("img_account.svg", info.getTeacherName());
  }

  Widget _iconWithText(String assetName, String content) {
    return Row(
      children: [
        SvgPicture.asset("assets/image/$assetName", color: Get.iconColor, height: 20, width: 20),
        const SizedBox(width: 4),
        Text(content),
      ],
    );
  }
}
