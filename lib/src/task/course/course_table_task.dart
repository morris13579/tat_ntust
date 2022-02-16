import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/course_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/task.dart';

import 'course_system_task.dart';

class CourseTableTask extends CourseSystemTask<CourseTableJson> {
  final String studentId;
  SemesterJson semester;

  CourseTableTask(this.studentId, this.semester) : super("CourseTableTask");

  @override
  Future<TaskStatus> execute() async {
    TaskStatus status = await super.execute();
    CourseMainInfo? value;
    if (status == TaskStatus.Success) {
      super.onStart(R.current.getCourse);
      if (semester.urlPath.isNotEmpty) {
        value = await CourseConnector.getCourseMainInfoList(studentId, semester,
            courseUrlPath: semester.urlPath);
      } else {
        value = await CourseConnector.getCourseMainInfoListByCourseId(semester);
      }
      super.onEnd();
      if (value != null) {
        CourseTableJson courseTable = CourseTableJson();
        courseTable.courseSemester = semester;
        courseTable.studentId = studentId;
        courseTable.studentName = value.studentName;
        //依照時間創建課表
        for (CourseMainInfoJson courseMainInfo in value.json) {
          CourseInfoJson courseInfo = CourseInfoJson();
          bool add = false;
          for (int i = 0; i < 7; i++) {
            Day day = Day.values[i];
            String? time = courseMainInfo.course.time[day];
            courseInfo.main = courseMainInfo;
            add |=
                courseTable.setCourseDetailByTimeString(day, time!, courseInfo);
          }
          if (!add) {
            //代表課程沒有時間
            courseTable.setCourseDetailByTime(
                Day.UnKnown, SectionNumber.T_UnKnown, courseInfo);
          }
        }
        if (studentId == Model.instance.getAccount()) {
          //只儲存自己的課表
          Model.instance.addCourseTable(courseTable);
          await Model.instance.saveCourseTableList();
        }
        result = courseTable;
        return TaskStatus.Success;
      } else {
        return await super.onError(R.current.getCourseError);
      }
    }
    return status;
  }
}
