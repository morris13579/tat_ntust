import 'package:dio/dio.dart';
import 'package:flutter_app/debug/log/Log.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course/course_semester.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

import 'core/connector_parameter.dart';

enum CourseConnectorStatus { LoginSuccess, LoginFail, UnknownError }

class CourseMainInfo {
  List<CourseMainInfoJson> json;
  String studentName;
}

class CourseConnector {
  static final String host = "https://courseselection.ntust.edu.tw";
  static final String _loginUrl = host;
  static final String _courseTableUrl = "$host/ChooseList/D01/D01";
  static final String _courseDetailUrl =
      "https://querycourse.ntust.edu.tw/querycourse/api/coursedetials";
  static final String _setTWUrl =
      "$host/Home/SetCulture?Culture=zh-TW&returnUrl=%2FChooseList%2FD01%2FD01";
  static final String _setENUrl =
      "$host/Home/SetCulture?Culture=en-US&returnUrl=%2FChooseList%2FD01%2FD01";
  static final String _courseSemestersUrl =
      "https://querycourse.ntust.edu.tw/querycourse/api/semestersinfo";

  static Future<CourseConnectorStatus> login() async {
    String result;
    try {
      ConnectorParameter parameter;
      parameter = ConnectorParameter(_loginUrl);
      result = await Connector.getRedirects(parameter);
      if (result.contains("DoLoginCB")) {
        return CourseConnectorStatus.LoginFail;
      }
      return CourseConnectorStatus.LoginSuccess;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return CourseConnectorStatus.LoginFail;
    }
  }

  static String clearString(String v) {
    return v.replaceAll("\n", "").replaceAll(" ", "");
  }

  static Future<CourseMainInfo> getCourseMainInfoList(
      String studentId, SemesterJson semester) async {
    var info = CourseMainInfo();
    try {
      ConnectorParameter parameter;
      Document tagNode;
      Element node, tableNode;
      List<Element> nodes, tableNodes;
      List<Day> dayEnum = [
        Day.Monday,
        Day.Tuesday,
        Day.Wednesday,
        Day.Thursday,
        Day.Friday,
        Day.Saturday,
        Day.Sunday,
      ];

      List<String> timeEnum = [
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
      String langUrl =
          (LanguageUtils.getLangIndex() == LangEnum.zh) ? _setTWUrl : _setENUrl;

      parameter = ConnectorParameter(langUrl);
      String result = await Connector.getRedirects(parameter);

      parameter = ConnectorParameter(_courseTableUrl);
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
        CourseMainJson courseMain = CourseMainJson();
        courseMain.id = clearString(k[0].text);
        courseMain.href = "";
        courseMain.name = k[1].text.replaceAll("  ", "").replaceAll("\n", "");
        courseMain.credits = clearString(k[2].text);
        courseMain.category = clearString(k[3].text);
        courseMain.note = clearString(k[5].text);
        TeacherJson teacher = TeacherJson();
        teacher.name = clearString(k[4].text);
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
              courseMain.time[day] += timeString + " ";
              ClassroomJson classroom = ClassroomJson();
              classroom.name = clearString(ts[j].innerHtml.split("<br>")[1]);
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
      info.studentName = tagNode.getElementsByClassName("text-success")[7].text;
      info.json = courseMainInfoList;
      return info;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<CourseExtraInfoJson> getCourseExtraInfo(
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
      print(courseExtraInfo);
      return courseExtraInfo;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<List<SemesterJson>> getCourseSemesters() async {
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
}
