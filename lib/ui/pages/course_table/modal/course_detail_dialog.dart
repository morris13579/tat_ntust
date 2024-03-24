import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/ui/components/input/input_field.dart';
import 'package:get/get.dart';
import 'package:sprintf/sprintf.dart';

class CourseDetailDialog extends StatelessWidget {
  const CourseDetailDialog(
      {super.key,
      required this.courseInfo,
      required this.onDetailTap,
      required this.onRemoveTap,
      required this.onMoodleTap,
      required this.time});

  final CourseInfoJson courseInfo;
  final String time;
  final Function() onDetailTap;
  final Function() onRemoveTap;
  final Function() onMoodleTap;

  @override
  Widget build(BuildContext context) {
    CourseMainJson course = courseInfo.main.course;
    String classroomName = courseInfo.main.getClassroomName();
    String teacherName = courseInfo.main.getTeacherName();

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 10.0, 10.0),
      title: Text(course.name),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            child: Text(sprintf("%s : %s", [R.current.courseId, course.id])),
            onLongPress: () async {
              course.id = await _showEditDialog(course.id);
              Model.instance.saveOtherSetting();
            },
          ),
          const SizedBox(height: 4),
          Text(sprintf("%s : %s", [R.current.time, time])),
          const SizedBox(height: 4),
          Text(sprintf("%s : %s", [R.current.location, classroomName])),
          const SizedBox(height: 4),
          Text(sprintf("%s : %s", [R.current.instructor, teacherName])),
        ],
      ),
      actions: [
        (courseInfo.main.course.select)
            ? TextButton(
                onPressed: () {
                  Get.back();
                  onMoodleTap();
                },
                child: Text(R.current.courseData),
              )
            : TextButton(
                onPressed: () {
                  Get.back();
                  onRemoveTap();
                },
                child: Text(R.current.remove),
              ),
        TextButton(
          onPressed: () {
            Get.back();
            onDetailTap();
          },
          child: Text(R.current.details),
        )
      ],
    );
  }

  Future<String> _showEditDialog(String value) async {
    final TextEditingController controller = TextEditingController();
    controller.text = value;
    String? v = await Get.dialog<String>(
      AlertDialog(
        contentPadding: const EdgeInsets.all(16.0),
        title: const Text('Edit'),
        content: Row(
          children: <Widget>[
            Expanded(
              child: InputField(
                controller: controller,
                hint: value,
              ),
            )
          ],
        ),
        actions: <Widget>[
          TextButton(
              child: Text(R.current.cancel),
              onPressed: () {
                Get.back(result: null);
              }),
          TextButton(
              child: Text(R.current.sure),
              onPressed: () {
                Get.back<String>(result: controller.text);
              })
        ],
      ),
    );
    return v ?? value;
  }
}
