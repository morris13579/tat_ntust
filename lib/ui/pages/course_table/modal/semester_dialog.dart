import 'package:flutter/material.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/ui/pages/course_table/component/semester_item.dart';

class SemesterDialog extends StatelessWidget {
  const SemesterDialog({super.key, required this.semesterList, required this.onSelected});

  final List<SemesterJson> semesterList;
  final Function(SemesterJson) onSelected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: double.minPositive,
        child: ListView.builder(
          itemCount: semesterList.length,
          shrinkWrap: true, //使清單最小化
          itemBuilder: (BuildContext context, int index) {
            return SemesterItem(
                semester: semesterList[index],
                onPress: onSelected);
          },
        ),
      ),
    );
  }
}
