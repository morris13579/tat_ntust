import 'package:dio/dio.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course/course_search_json.dart';
import 'package:flutter_app/src/model/course/course_semester.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_course_task.dart';
import 'package:flutter_app/src/task/task_flow.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

import 'core/connector_parameter.dart';

enum CourseConnectorStatus { loginSuccess, loginFail, unknownError }

class CourseMainInfo {
  List<CourseMainInfoJson> json;
  String studentName;

  CourseMainInfo({required this.json, required this.studentName});
}

class CourseConnector {
  static const host = "https://courseselection.ntust.edu.tw";
  static const _loginUrl = host;
  static const _courseTableUrl = "$host/ChooseList/D01/D01";
  static const _setTWUrl = "$host/Home/SetCulture?Culture=zh-TW";
  static const _setENUrl = "$host/Home/SetCulture?Culture=en-US";
  static const queryHost = "https://querycourse.ntust.edu.tw";
  static const _courseDetailUrl = "$queryHost/querycourse/api/coursedetials";
  static const _courseSearchUrl = "$queryHost/querycourse/api/courses";
  static const _courseSemestersUrl = "$queryHost/querycourse/api/semestersinfo";

  static List<Day> dayEnum = [
    Day.monday,
    Day.tuesday,
    Day.wednesday,
    Day.thursday,
    Day.friday,
    Day.saturday,
    Day.sunday,
  ];

  static List<String> timeEnum = [
    "1",
    "2",
    "3",
    "4",
    "N",
    "5",
    "6",
    "7",
    "8",
    "9",
    "A",
    "B",
    "C",
    "D"
  ];

  static var dayString = ["M", "T", "W", "R", "F", "S", "U"];

  static Future<CourseConnectorStatus> login() async {
    String result;
    try {
      ConnectorParameter parameter;
      parameter = ConnectorParameter(_loginUrl);
      result = await Connector.getRedirects(parameter);
      if (result.contains("DoLoginCB")) {
        return CourseConnectorStatus.loginFail;
      }
      return CourseConnectorStatus.loginSuccess;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return CourseConnectorStatus.loginFail;
    }
  }

  static Future<List<SemesterJson>?> getCourseSemester() async {
    try {
      ConnectorParameter parameter;
      Document tagNode;
      Element? node;
      List<Element> nodes;
      List<SemesterJson> value = [];
      String langUrl =
          (LanguageUtils.getLangIndex() == LangEnum.zh) ? _setTWUrl : _setENUrl;

      parameter = ConnectorParameter(host);
      String result = await Connector.getRedirects(parameter); //sso login

      parameter = ConnectorParameter(langUrl);
      result = await Connector.getRedirects(parameter);

      parameter = ConnectorParameter(host);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      node = tagNode.getElementById("navigation");
      if(node == null) {
        throw Exception("navigation tag not found");
      }
      nodes = node
          .getElementsByClassName("dropdown")[3]
          .getElementsByClassName("dropdown-menu")[0]
          .getElementsByTagName("a");
      for (var i in nodes) {
        if (i.text.split("(").length > 1) {
          value.add(SemesterJson(
            year: i.text.split("(")[1].substring(0, 3),
            semester: i.text.split("(")[1].substring(3, 4),
            urlPath: i.attributes["href"]!,
          ));
        } else {
          value.add(SemesterJson(
            year: i.text,
            semester: "",
            urlPath: i.attributes["href"]!,
          ));
        }
      }
      return value;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static String clearString(String v) {
    return v.replaceAll("\n", "").replaceAll(" ", "");
  }

  static Future<CourseMainInfo?> getCourseMainInfoList(
      String studentId, SemesterJson semester,
      {String? courseUrlPath}) async {
    if (courseUrlPath != null) {
      courseUrlPath = "$host/$courseUrlPath";
    }
    String courseUrl = courseUrlPath ?? _courseTableUrl;
    try {
      ConnectorParameter parameter;
      Document tagNode;
      Element node, tableNode;
      List<Element> nodes, tableNodes;
      String langUrl =
          (LanguageUtils.getLangIndex() == LangEnum.zh) ? _setTWUrl : _setENUrl;

      parameter = ConnectorParameter(langUrl);
      String result = await Connector.getRedirects(parameter);

      parameter = ConnectorParameter(courseUrl);
      result = await Connector.getDataByGet(parameter);
      tagNode = parse(result);
      List<CourseMainInfoJson> courseMainInfoList = [];
      node = tagNode.getElementsByTagName("table")[2];
      nodes = node.getElementsByTagName("tr");

      tableNode = tagNode.getElementsByTagName("table")[3];
      tableNodes = tableNode.getElementsByTagName("tr");
      tableNodes = tableNodes.getRange(1, tableNodes.length).toList();

      for (var i in nodes.getRange(1, nodes.length).toList()) {
        var k = i.getElementsByTagName("td");
        //課碼	課程名稱	學分數	必、選修	上課教師	備註
        CourseMainInfoJson courseMainInfo = CourseMainInfoJson();
        CourseMainJson courseMain = CourseMainJson(
          id: clearString(k[0].text),
          href: "",
          name: k[1].text.replaceAll("  ", "").replaceAll("\n", ""),
          credits: clearString(k[2].text),
          category: clearString(k[3].text),
          note: clearString(k[5].text),
          hours: "",
          time: {},
        );
        TeacherJson teacher =
            TeacherJson(name: clearString(k[4].text), href: "");
        for (int j = 0; j < 7; j++) {
          Day day = dayEnum[j]; //初始化
          courseMain.time[day] = "";
        }
        List<String> classRoomTemp = [];
        for (int j = 0; j < 7; j++) {
          Day day = dayEnum[j];
          for (int k = 0; k < 14; k++) {
            String timeString = timeEnum[k];
            var ts = tableNodes[k].getElementsByTagName("td");
            ts = ts.getRange(2, ts.length).toList();
            if (ts[j].text.contains(courseMain.name)) {
              courseMain.time[day] = "${courseMain.time[day]!}$timeString ";
              ClassroomJson classroom = ClassroomJson(
                  name: clearString(ts[j].innerHtml.split("<br>")[1]),
                  href: '');
              if (classRoomTemp.contains(classroom.name)) {
                continue;
              }
              courseMainInfo.classroom.add(classroom);
              classRoomTemp.add(classroom.name);
            }
          }
        }
        courseMainInfo.teacher.add(teacher);
        courseMainInfo.course = courseMain;
        courseMainInfoList.add(courseMainInfo);
      }
      var info = CourseMainInfo(
        studentName: tagNode.getElementsByClassName("text-success")[7].text,
        json: courseMainInfoList,
      );
      return info;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<CourseMainInfo?> getCourseMainInfoListByCourseId(
      SemesterJson semester) async {
    ConnectorParameter parameter;

    var courseIds = await Model.instance.getScore().getCourseIdBySemester(semester);

    if(courseIds.isEmpty) {
      // 如果成績查詢系統抓不到資料，改用moodle查詢課程代碼
      var taskFlow = TaskFlow();
      var task = MoodleCourseTask(semester);
      taskFlow.addTask(task);
      await taskFlow.start();
      courseIds = task.result;
    }

    try {
      List<CourseMainInfoJson> courseMainInfoList = [];
      for (var courseId in courseIds) {
        Map<String, dynamic> data = {
          "CourseName": "",
          "CourseNo": courseId,
          "CourseNotes": "",
          "CourseTeacher": "",
          "Dimension": "",
          "ForeignLanguage": 0,
          "language": (LanguageUtils.getLangIndex() == LangEnum.zh) ? "zh" : "en",
          "OnleyNTUST": 0,
          "OnlyGeneral": 0,
          "OnlyMaster": 0,
          "OnlyNode": 0,
          "OnlyUnderGraduate": 0,
          "Semester": "${semester.year}${semester.semester}"
        };
        parameter = ConnectorParameter(_courseSearchUrl, data: data);
        var json = await Connector.getDataByPostResponse(parameter);
        if (json.data.length == 0) continue;
        // 同個課程代碼如果不同教室會有多筆資料
        for(var data in json.data) {
          CourseSearchJson info = CourseSearchJson.fromJson(data);
          CourseMainInfoJson courseMainInfo = CourseMainInfoJson();
          CourseMainJson courseMain = CourseMainJson(
            id: courseId,
            href: "",
            name: info.courseName,
            credits: info.creditPoint,
            category: "",
            note: info.contents,
            hours: "",
            time: {},
          );
          for (int j = 0; j < 7; j++) {
            Day day = dayEnum[j]; //初始化
            courseMain.time[day] = "";
          }
          for (var t in info.node.split(",")) {
            if (t.isEmpty) {
              continue;
            }
            int dayIndex = dayString.indexOf(t.substring(0, 1));
            int timeIndex;
            try {
              timeIndex = int.parse(t.substring(1)) - 1;
            } catch (e) {
              timeIndex = t.codeUnitAt(1) - 'A'.codeUnitAt(0) + 10;
            }
            Day day = dayEnum[dayIndex];
            courseMain.time[day] =
            "${courseMain.time[day]!}${timeEnum[timeIndex]} ";
          }
          TeacherJson teacher = TeacherJson(name: info.courseTeacher, href: "");
          ClassroomJson classroom =
          ClassroomJson(name: info.classRoomNo, href: '');
          courseMainInfo.classroom.add(classroom);
          courseMainInfo.teacher.add(teacher);
          courseMainInfo.course = courseMain;
          courseMainInfoList.add(courseMainInfo);
        }
      }
      var info = CourseMainInfo(
        studentName: "",
        json: courseMainInfoList,
      );
      return info;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<CourseExtraInfoJson?> getCourseExtraInfo(
      String courseId, SemesterJson semester) async {
    try {
      ConnectorParameter parameter;
      Map<String, String> data = {
        "semester": "${semester.year}${semester.semester}",
        "course_no": courseId,
        "language": (LanguageUtils.getLangIndex() == LangEnum.zh) ? "zh" : "en"
      };
      parameter = ConnectorParameter(_courseDetailUrl);
      parameter.data = data;
      Response result = await Connector.getDataByGetResponse(parameter);
      CourseExtraInfoJson courseExtraInfo =
          CourseExtraInfoJson.fromJson(result.data[0]);
      return courseExtraInfo;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<List<SemesterJson>?> getCourseSemesters() async {
    try {
      ConnectorParameter parameter;
      parameter = ConnectorParameter(_courseSemestersUrl);
      Response result = await Connector.getDataByGetResponse(parameter);
      List<CourseSemesterJson> courseSemester = (result.data as List)
          .map((e) => CourseSemesterJson.fromJson(e))
          .toList();
      SemesterJson semester = SemesterJson(
          year: courseSemester[0].semester.substring(0, 3),
          semester: courseSemester[0].semester.substring(3, 4));
      return [semester];
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<List<CourseMainInfoJson>?> searchCourse(
      SemesterJson semester, String keyword) async {
    List<CourseMainInfoJson> courseMainInfoList = [];

    try {
      ConnectorParameter parameter;
      Map<String, dynamic> data = {
        "CourseName": "",
        "CourseNo": keyword,
        "CourseNotes": "",
        "CourseTeacher": "",
        "Dimension": "",
        "ForeignLanguage": 0,
        "language": (LanguageUtils.getLangIndex() == LangEnum.zh) ? "zh" : "en",
        "OnleyNTUST": 0,
        "OnlyGeneral": 0,
        "OnlyMaster": 0,
        "OnlyNode": 0,
        "OnlyUnderGraduate": 0,
        "Semester": "${semester.year}${semester.semester}"
      };
      parameter = ConnectorParameter(_courseSearchUrl, data: data);
      var json = await Connector.getDataByPostResponse(parameter);
      if (json.data.length == 0) {
        Map<String, dynamic> data = {
          "CourseName": keyword,
          "CourseNo": "",
          "CourseNotes": "",
          "CourseTeacher": "",
          "Dimension": "",
          "ForeignLanguage": 0,
          "language":
              (LanguageUtils.getLangIndex() == LangEnum.zh) ? "zh" : "en",
          "OnleyNTUST": 0,
          "OnlyGeneral": 0,
          "OnlyMaster": 0,
          "OnlyNode": 0,
          "OnlyUnderGraduate": 0,
          "Semester": "${semester.year}${semester.semester}"
        };
        parameter = ConnectorParameter(_courseSearchUrl, data: data);
        json = await Connector.getDataByPostResponse(parameter);
      }
      for (var item in json.data) {
        CourseSearchJson info = CourseSearchJson.fromJson(item);

        CourseMainInfoJson courseMainInfo = CourseMainInfoJson();
        CourseMainJson courseMain = CourseMainJson(
          id: info.courseNo,
          href: "",
          name: info.courseName,
          credits: info.creditPoint,
          category: "",
          note: info.contents,
          hours: "",
          time: {},
        );
        for (int j = 0; j < 7; j++) {
          Day day = dayEnum[j]; //初始化
          courseMain.time[day] = "";
        }

        for (var t in info.node.split(",")) {
          if (t.isEmpty) {
            continue;
          }
          int dayIndex = dayString.indexOf(t.substring(0, 1));
          int timeIndex;
          try {
            timeIndex = int.parse(t.substring(1)) - 1;
          } catch (e) {
            timeIndex = t.codeUnitAt(1) - 'A'.codeUnitAt(0) + 10;
          }
          Day day = dayEnum[dayIndex];
          courseMain.time[day] =
              "${courseMain.time[day]!}${timeEnum[timeIndex]} ";
        }
        TeacherJson teacher = TeacherJson(name: info.courseTeacher, href: "");
        ClassroomJson classroom =
            ClassroomJson(name: info.classRoomNo, href: '');
        courseMainInfo.classroom.add(classroom);
        courseMainInfo.teacher.add(teacher);
        courseMainInfo.course = courseMain;
        courseMainInfoList.add(courseMainInfo);
      }
      return courseMainInfoList;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }
}
