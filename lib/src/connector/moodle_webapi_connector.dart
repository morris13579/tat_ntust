import 'package:flutter_app/debug/log/Log.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/util/html_utils.dart';

enum MoodleWebApiConnectorStatus { LoginSuccess, LoginFail, UnknownError }

class MoodleWebApiConnector {
  static const String host = "https://moodle.ntust.edu.tw";
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

  static Future<String> getCourseUrl(String courseId) async {
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
      throw Exception("Course Id not find");
    } catch (e) {
      throw e;
    }
  }

  static Future<List<MoodleCoreCourseGetContents>?> getCourseDirectory(
      String id) async {
    ConnectorParameter parameter;
    List result;
    try {
      String courseId = await getCourseUrl(id);
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

  static Future<MoodleModForumGetForumDiscussionsPaginated?> getCourseMessage(
      String id) async {
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
            if (j.name.contains("公佈欄")) {
              forumId = j.instance.toString();
              break;
            }
          }
        }
        if (forumId != null) {
          break;
        }
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

  static Future<bool> testMoodleWebApi() async {
    try {
      var r = await DioConnector.instance.dio.get(_webAPIUrl);
      return 200 == r.statusCode;
    } catch (e) {
      return false;
    }
  }
}
