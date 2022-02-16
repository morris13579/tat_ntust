import 'package:dio/dio.dart';
import 'package:flutter_app/debug/log/Log.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_user_get_grades_table.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_score.dart';
import 'package:flutter_app/src/util/html_utils.dart';
import 'package:html/parser.dart';

enum MoodleWebApiConnectorStatus { LoginSuccess, LoginFail, UnknownError }

class MoodleWebApiConnector {
  static const String host = "https://moodle2.ntust.edu.tw";
  static const String _webAPIUrl = "$host/webservice/rest/server.php";
  static const String _webAPILoginUrl = "$host/login/token.php";

  static String? wsToken;

  static Future<MoodleWebApiConnectorStatus> login(
      String account, String password) async {
    ConnectorParameter parameter;
    Map result;
    try {
      parameter = ConnectorParameter(_webAPILoginUrl);
      parameter.data = {
        "username": account,
        "password": password,
        "service": "moodle_mobile_app"
      };
      result = await Connector.getJsonByPost(parameter);
      if (result.containsKey("token")) {
        wsToken = result["token"];
        return MoodleWebApiConnectorStatus.LoginSuccess;
      }
      return MoodleWebApiConnectorStatus.LoginFail;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return MoodleWebApiConnectorStatus.LoginFail;
    }
  }

  static Future<String?> getCourseUrl(String courseId) async {
    Map result;
    ConnectorParameter parameter;
    try {
      parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "wsfunction": "core_webservice_get_site_info",
        "wstoken": wsToken
      };
      result = await Connector.getJsonByPost(parameter);
      String userId = result["userid"].toString();

      parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "wsfunction": "core_enrol_get_users_courses",
        "wstoken": wsToken,
        "userid": userId
      };
      for (var i in (await Connector.getJsonByPost(parameter) as List)) {
        if ((i["fullname"] as String).contains(courseId)) {
          return i["id"].toString();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<MoodleCoreCourseGetContents>?> getCourseDirectory(
      String courseId) async {
    ConnectorParameter parameter;
    List result;
    try {
      parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "wsfunction": "core_course_get_contents",
        "wstoken": wsToken,
        "courseid": courseId
      };
      result = await Connector.getJsonByPost(parameter);
      List<MoodleCoreCourseGetContents> v =
          result.map((e) => MoodleCoreCourseGetContents.fromJson(e)).toList();
      for (var i in v) {
        for (var j in i.modules) {
          j.name = HtmlUtils.clean(j.name);
        }
      }
      return v;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<MoodleModForumGetForumDiscussionsPaginated?>
      getCourseAnnouncement(String id) async {
    ConnectorParameter parameter;
    Map result;
    try {
      List<MoodleCoreCourseGetContents>? v = await getCourseDirectory(id);
      if (v == null) {
        throw Exception("List<MoodleCoreCourseGetContents> is null");
      }
      String? forumId;
      for (var i in v) {
        if (i.name.contains("一般")) {
          for (var j in i.modules) {
            if (j.name.contains("公告")) {
              forumId = j.instance.toString();
              break;
            }
          }
        }
        if (forumId != null) {
          break;
        }
      }
      if (forumId == null) {
        throw Exception("forumId is null");
      }

      parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "wsfunction": "mod_forum_get_forum_discussions_paginated",
        "wstoken": wsToken,
        "forumid": forumId,
        "sortby": "timemodified",
        "sortdirection": "desc",
      };
      result = await Connector.getJsonByPost(parameter);
      return MoodleModForumGetForumDiscussionsPaginated.fromJson(
          result as Map<String, dynamic>);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<List<MoodleCoreEnrolGetUsers>?> getMember(String id) async {
    ConnectorParameter parameter;
    Response result;
    List<MoodleCoreEnrolGetUsers> userinfo = [];
    try {
      parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "wsfunction": "core_enrol_get_enrolled_users",
        "wstoken": wsToken,
        "courseid": id,
        "options[0][name]": "limitfrom",
        "options[0][value]": "0",
        "options[1][name]": "limitnumber",
        "options[1][value]": "0",
        "options[2][name]": "sortby",
        "options[2][value]": "siteorder",
      };
      result = await Connector.getDataByPostResponse(parameter);
      for (var i in result.data) {
        var user = MoodleCoreEnrolGetUsers.fromJson(i as Map<String, dynamic>);
        if (!user.fullName.contains("老師")) userinfo.add(user);
      }
      return userinfo;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<List<MoodleScoreItem>?> getScore(String id) async {
    ConnectorParameter parameter;
    Map result;
    try {
      parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "wsfunction": "core_webservice_get_site_info",
        "wstoken": wsToken
      };
      result = await Connector.getJsonByPost(parameter);
      String userId = result["userid"].toString();

      parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "wsfunction": "gradereport_user_get_grades_table",
        "wstoken": wsToken,
        "courseid": id,
        "userid": userId
      };
      List<MoodleScoreItem> value = [];
      result = await Connector.getJsonByPost(parameter);
      var grade = MoodleGradeReportUserGetGradesTable.fromJson(
          result as Map<String, dynamic>);
      for (var i = grade.tables[0].tableData.length - 1; i >= 1; i--) {
        var g = grade.tables[0].tableData[i];
        var tagNode = parse(g.itemName.content);
        var name;
        if (tagNode
            .getElementsByClassName("gradeitemheader")[0]
            .attributes
            .containsKey("href")) {
          name = tagNode.getElementsByTagName("a")[0].text;
        } else {
          name = tagNode.getElementsByTagName("span")[0].attributes["title"]!;
        }
        value.add(MoodleScoreItem(
          name: name,
          weight: HtmlUtils.clean(g.weight.content),
          score: HtmlUtils.clean(g.grade.content),
          fullRange: HtmlUtils.clean(g.range.content),
          percentage: HtmlUtils.clean(g.percentage.content),
          feedback: HtmlUtils.clean(g.feedback.content),
          contribute: HtmlUtils.clean(g.contributiontocoursetotal.content),
        ));
      }

      return value;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<bool> testMoodleWebApi() async {
    try {
      var r = await DioConnector.instance.dio.get(_webAPIUrl);
      return 200 == r.statusCode;
    } catch (e) {
      return false;
    }
  }
}
