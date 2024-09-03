import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/cache_task.dart';
import 'package:flutter_app/src/task/course/course_search_task.dart';
import 'package:flutter_app/src/task/course/course_semester_task.dart';
import 'package:flutter_app/src/task/course/course_table_task.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_course_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sprintf/sprintf.dart';

class CourseModel {
  Future<List<SemesterJson>> getSemesterList(String studentId) async {
    //顯示選擇學期
    if (Model.instance.getSemesterList().isEmpty) {
      TaskFlow taskFlow = TaskFlow();
      var task = CourseSemesterTask(studentId);
      taskFlow.addTask(task);
      if (await taskFlow.start()) {
        Model.instance.setSemesterJsonList(task.result);
      }
    }
    return Model.instance.getSemesterList();
  }

  CourseTableJson? getCourseSettingInfo() {
    CourseTableJson? courseTable = Model.instance.getCourseSetting().info;
    return courseTable;
  }

  List<CourseTableJson> getCacheCourseTableList() {
    return Model.instance.getCourseTableList();
  }

  void saveFavoriteCourse(CourseTableJson info) {
    saveCourse(info);
    Model.instance.clearSemesterJsonList(); //須清除已儲存學期
  }

  Future<void> removeFavoriteCourse(CourseTableJson info) async {
    Model.instance.removeCourseTable(info);
    await Model.instance.saveCourseTableList();
  }

  Future<CourseTableJson> getCourseTable(
      {SemesterJson? semesterSetting, bool refresh = false}) async {
    String studentId = Model.instance.getAccount();
    SemesterJson? semesterJson;

    if (semesterSetting == null) {
      await getSemesterList(studentId);
      semesterJson = Model.instance.getSemesterJsonItem(0);
    } else {
      semesterJson = semesterSetting;
    }

    if (semesterJson == null) {
      throw Exception();
    }

    if (!semesterJson.isValid) {
      MyToast.show(
        sprintf(R.current.selectSemesterWarning, [semesterJson.year]),
        toastLength: Toast.LENGTH_LONG,
      );
      SemesterJson? select =
          await CourseSemesterTask.selectSemesterDialog(allowSelectNull: true);
      if (select == null) {
        throw Exception();
      }
      semesterJson.year = select.year;
      semesterJson.semester = select.semester;
      var s = Model.instance.getSemesterList();
      List<SemesterJson> v = [];
      for (var i in s) {
        if (!v.contains(i)) {
          v.add(i);
        }
      }
      Model.instance.setSemesterJsonList(v);
    }

    CourseTableJson? courseTable;
    if (!refresh) {
      //是否要去找暫存的
      courseTable =
          Model.instance.getCourseTable(studentId, semesterSetting); //去取找是否已經暫存
    }
    if (courseTable == null) {
      //代表沒有暫存的需要爬蟲
      TaskFlow taskFlow = TaskFlow();
      final task = CourseTableTask(studentId, semesterJson);
      taskFlow.addTask(task);
      if (await taskFlow.start()) {
        courseTable = task.result;
      } else {
        throw Exception();
      }
    }
    return courseTable;
  }

  Future<List<CourseMainInfoJson>> getQueryCourse(SemesterJson semester, String keyword) async {
    final taskFlow = TaskFlow();
    CacheTask task = CourseSearchTask(semester, keyword);
    taskFlow.addTask(task);
    if (await taskFlow.start()) {
      return task.result as List<CourseMainInfoJson>;
    }
    return [];
  }

  void saveCourse(CourseTableJson table) {
    Model.instance.getCourseSetting().info = table; //儲存課表
    Model.instance.saveCourseSetting();
  }
}
