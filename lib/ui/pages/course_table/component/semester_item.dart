import 'package:flutter/material.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:get/get.dart';

class SemesterItem extends StatelessWidget {
  const SemesterItem({super.key, required this.semester, required this.onPress});

  final SemesterJson semester;
  final Function(SemesterJson) onPress;

  @override
  Widget build(BuildContext context) {
    String semesterString = semester.year;
    if (semester.semester.isNotEmpty) {
      semesterString += ("-${semester.semester}");
    }
    return TextButton(
      child: Text(semesterString),
      onPressed: () async {
        Get.back();
        onPress(semester);
      },
    );
  }
}
