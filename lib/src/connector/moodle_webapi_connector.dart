import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_login_page.dart';
import 'package:flutter_app/src/entity/moodle_token_entity.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/grade/tables.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_task.dart';
import 'package:flutter_app/src/util/html_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:get/get.dart' as g;

enum MoodleWebApiConnectorStatus { loginSuccess, loginFail, unknownError }

class MoodleWebApiConnector {
  static const String host = "https://moodle2.ntust.edu.tw";
  static const String _webAPIUrl = "$host/webservice/rest/server.php";
  static const String _webAPILoginUrl = "$host/login/token.php";
  static String moodleLoginUrl =
      "$host/admin/tool/mobile/launch.php?service=moodle_mobile_app&passport=${Random.secure().nextInt(500)}&urlscheme=moodlemobile&lang=zh_tw";

  static String? wsToken;
  static String? privateToken;

  static Future<MoodleWebApiConnectorStatus> login(String account, String password) async {
    try {
      final tokenData = (await g.Get.to(() => LoginMoodlePage(username: account, password: password))) as MoodleTokenEntity?;
      if(tokenData == null) {
        return MoodleWebApiConnectorStatus.loginFail;
      }

      wsToken = tokenData.token;
      privateToken = tokenData.privateToken;
      MoodleTask.isLogin = true;

      await Model.instance.setMoodleToken(tokenData);

      return MoodleWebApiConnectorStatus.loginSuccess;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
    }

    return MoodleWebApiConnectorStatus.loginFail;
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
            // 113-1 學期新增 課程公佈欄、課程討論區 取代公告
            if (j.name.contains("公告") || j.name.contains("課程公佈欄")) {
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

  static Future<List<String>> getCourseIds(SemesterJson semester) async {
    ConnectorParameter parameter;
    Response result;
    try {
      parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "wsfunction": "core_course_get_enrolled_courses_by_timeline_classification",
        "classification": "inprogress",
        "wstoken": wsToken
      };
      result = await Connector.getDataByPostResponse(parameter);

      var courseList = result.data["courses"] as List;
      // 取得moodle課程資料
      return courseList
          .map((e) => (e["idnumber"] as String)
              .replaceAll("${semester.year}${semester.semester}", ""))
          .toList();
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return [];
    }
  }

  static Future<SemesterJson?> getCurrentSemester() async {
    if (wsToken == null) {
      await MoodleWebApiConnector.login(
          Model.instance.getAccount(), Model.instance.getPassword());
    }
    ConnectorParameter parameter;
    Response result;
    try {
      parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "wsfunction":
            "core_course_get_enrolled_courses_by_timeline_classification",
        "classification": "inprogress",
        "wstoken": wsToken
      };
      result = await Connector.getDataByPostResponse(parameter);

      var courseList = result.data["courses"] as List;
      var id = courseList.first["idnumber"] as String;

      var year = id.substring(0, 3);
      var semester = id.substring(3, 4);
      return SemesterJson(year: year, semester: semester);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<TablesEntity?> getScore(String id) async {
    ConnectorParameter parameter;
    Map<String, dynamic> result;
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
      result = await Connector.getJsonByPost(parameter);
      var tableData = TablesEntity.fromJson(result["tables"][0]);
      return tableData;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<bool> testMoodleWebApi() async {
    try {
      var r = await DioConnector.instance.dio.get(_webAPIUrl);
      print(r.statusCode);
      return 200 == r.statusCode;
    } catch (e) {
      return false;
    }
  }

  static Future<MoodleProfileEntity?> getProfile({isRetry = false}) async {
    if (wsToken == null) {
      await MoodleWebApiConnector.login(Model.instance.getAccount(), Model.instance.getPassword());
    }
    try {
      var parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "wsfunction": "core_webservice_get_site_info",
        "wstoken": wsToken
      };
      var result = await Connector.getDataByPostResponse(parameter);
      if((result.data as Map<String, dynamic>).containsKey("errorcode")) {
        if(isRetry) {
          Model.instance.clearMoodleToken();
          MyToast.show(R.current.loginMoodleWebApiError);
          return null;
        }

        await MoodleWebApiConnector.login(Model.instance.getAccount(), Model.instance.getPassword());
        return getProfile(isRetry: true);
      }
      return MoodleProfileEntity.fromJson(result.data);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<MoodleSettingEntity?> getSettings() async {
    if (wsToken == null) {
      await MoodleWebApiConnector.login(
          Model.instance.getAccount(), Model.instance.getPassword());
    }
    try {
      var parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "wsfunction": "core_message_get_user_notification_preferences",
        "wstoken": wsToken
      };
      var result = await Connector.getDataByPostResponse(parameter);
      return MoodleSettingEntity.fromJson(result.data);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  static Future<void> toggleSetting(String key, List<String> values) async {
    if (wsToken == null) {
      await MoodleWebApiConnector.login(
          Model.instance.getAccount(), Model.instance.getPassword());
    }
    try {
      var parameter = ConnectorParameter(_webAPIUrl);
      parameter.data = {
        "moodlewsrestformat": "json",
        "wsfunction": "core_user_update_user_preferences",
        "wstoken": wsToken,
        "preferences[0][type]": "${key}_enabled",
        "preferences[0][value]": values.join(","),
        "moodlewssettingfilter": true,
        "moodlewssettingfileurl": true
      };

      var result = await Connector.getDataByPostResponse(parameter);
      print(result);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
    }
  }
}
