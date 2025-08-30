import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/connector/score_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/score/score_system_task.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:get/get.dart';
import 'package:numberpicker/numberpicker.dart';

class CourseSemesterTask extends ScoreSystemTask<List<SemesterJson>> {
  final String id;

  CourseSemesterTask(this.id) : super("CourseSemesterTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    if (status == TaskStatus.success) {
      List<SemesterJson>? value;
      super.onStart(R.current.getCourseSemester);

      value = await CourseConnector.getCourseSemester();

      try {
        // 從選課系統取得資料
        ScoreRankJson? v = await ScoreConnector.getScoreRank();
        Model.instance.setScore(v!);
        Model.instance.saveScore();
        value ??= [];
        for (var i in v.info) {
          if (!value.contains(i.semester)) {
            value.add(i.semester);
          }
        }

        // 從moodle 取得資料
        var currentSemester = await MoodleWebApiConnector.getCurrentSemester();
        if (currentSemester != null &&
            value
                .where((element) =>
                    element.year == currentSemester.year &&
                    element.semester == currentSemester.semester)
                .isEmpty) {
          value.add(currentSemester);
        }

        // 排序年度/學期
        value.sort((a, b) {
          final yearA = int.tryParse(a.year) ?? 0;
          final yearB = int.tryParse(b.year) ?? 0;
          final semesterA = int.tryParse(a.semester) ?? 0;
          final semesterB = int.tryParse(b.semester) ?? 0;

          int yearCompare = yearB.compareTo(yearA);
          if (yearCompare != 0) {
            return yearCompare;
          } else {
            return semesterB.compareTo(semesterA);
          }
        });
      } catch (e) {
        Log.d(e);
      }
      super.onEnd();
      if (value != null) {
        result = value;
        return TaskStatus.success;
      } else {
        result = [];
        result.add((await selectSemesterDialog())!);
        return TaskStatus.success;
        //return await super.onError(R.current.getCourseSemesterError);
      }
    }
    return status;
  }

  static Future<SemesterJson?> selectSemesterDialog(
      {allowSelectNull = false}) async {
    DateTime dateTime = DateTime.now();
    int year = dateTime.year - 1911;
    int semester = (dateTime.month <= 7 && dateTime.month >= 1) ? 2 : 1;
    if (dateTime.month <= 7) {
      year--;
    }
    SemesterJson before =
        SemesterJson(semester: semester.toString(), year: year.toString());
    SemesterJson? select = await Get.dialog<SemesterJson>(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(R.current.selectSemester),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: NumberPicker(
                          value: year,
                          minValue: 100,
                          maxValue: 120,
                          onChanged: (value) => setState(() => year = value)),
                    ),
                    Expanded(
                      child: NumberPicker(
                          value: semester,
                          minValue: 1,
                          maxValue: 3,
                          onChanged: (value) =>
                              setState(() => semester = value)),
                    ),
                  ],
                )
              ],
            ),
            actions: [
              TextButton(
                  child: Text(R.current.sure),
                  onPressed: () {
                    Get.back<SemesterJson>(
                      result: SemesterJson(
                        semester: (semester == 3) ? "H" : semester.toString(),
                        year: year.toString(),
                      ),
                    );
                  })
            ],
          );
        },
      ),
      barrierDismissible: false,
    );
    if (!allowSelectNull) {
      select ??= before;
    }
    return select;
  }
}
