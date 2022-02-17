import 'dart:convert';

import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions_paginated.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_score.dart';
import 'package:flutter_app/src/task/dialog_task.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheTask<T> extends DialogTask<T> {
  List<String> _keyInfo = []; //if not null will enable the cache
  CacheTask(String name) : super(name);

  void initCache(String name, String id) {
    _keyInfo = [name, id];
  }

  bool get cacheEnable {
    return _keyInfo.length != 0;
  }

  String get _key {
    return _keyInfo[0];
  }

  String get _id {
    return _keyInfo[1];
  }

  @override
  Future<TaskStatus> execute() async {
    super.execute();
    return TaskStatus.Success;
  }

  Future<bool> get hasCache async {
    if (cacheEnable) {
      var pref = await SharedPreferences.getInstance();
      String? value = pref.getString(_key);
      if (value != null) {
        var obj = getObject(jsonDecode(value)[_id]);
        if (obj != null) {
          result = obj;
          return true;
        }
      }
    }
    return false;
  }

  dynamic getObject(dynamic v) {
    try {
      switch (T.toString()) {
        case "List<MoodleCoreCourseGetContents>":
          return (v as List)
              .map((e) => MoodleCoreCourseGetContents.fromJson(e))
              .toList();
        case "List<MoodleCoreEnrolGetUsers>":
          return (v as List)
              .map((e) => MoodleCoreEnrolGetUsers.fromJson(e))
              .toList();
        case "List<MoodleScoreItem>":
          return (v as List).map((e) => MoodleScoreItem.fromJson(e)).toList();
        case "CourseExtraInfoJson":
          return CourseExtraInfoJson.fromJson(v);
        case "MoodleModForumGetForumDiscussionsPaginated":
          return MoodleModForumGetForumDiscussionsPaginated.fromJson(v);

        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  set result(T v) {
    if (cacheEnable && v != null) {
      SharedPreferences.getInstance().then((value) {
        var obj = jsonDecode(value.getString(_key) ?? "{}");
        obj[_id] = v;
        value.setString(_key, jsonEncode(obj));
      });
    }

    super.result = v;
  }

  @override
  Future<TaskStatus> onError(String message) {
    return super.onError(message);
  }

  @override
  Future<TaskStatus> onErrorParameter(ErrorDialogParameter parameter) async {
    return super.onErrorParameter(parameter);
  }
}
