import 'dart:convert';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_task.dart';
import 'package:flutter_app/src/task/task.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoodleSupportTask<T> extends MoodleTask<T> {
  String _courseId;
  late String findId;
  static Map<String, String> _cache = {};
  static bool _firstLoadCache = true;
  final String _prefKey = "cache_moodle_support";

  MoodleSupportTask(name, this._courseId) : super(name);

  @override
  Future<TaskStatus> execute() async {
    if (_firstLoadCache) {
      _firstLoadCache = false;
      await _loadCache();
    }
    TaskStatus status = await super.execute();
    if (status == TaskStatus.Success) {
      super.onStart(R.current.checkMoodleSupport);
      if (_cache.keys.contains(_courseId)) {
        findId = _cache[_courseId]!;
        return status;
      }
      try {
        if (useMoodleWebApi)
          findId = (await MoodleWebApiConnector.getCourseUrl(_courseId))!;
        else
          findId = (await MoodleConnector.getCourseUrl(_courseId))!;
        super.onEnd();
        _cache[_courseId] = findId;
        await _saveCache();
      } catch (e) {
        super.onEnd();
        ErrorDialogParameter parameter = ErrorDialogParameter(
          title: R.current.warning,
          dialogType: DialogType.INFO,
          desc: R.current.unSupportThisClass,
          okResult: false,
          btnOkText: R.current.sure,
          offCancelBtn: true,
        );
        return await super.onErrorParameter(parameter);
      }
    }
    return status;
  }

  Future<void> _saveCache() async {
    try {
      var pref = await SharedPreferences.getInstance();
      pref.setString(_prefKey, jsonEncode(_cache));
    } catch (e) {}
  }

  Future<void> _loadCache() async {
    try {
      var pref = await SharedPreferences.getInstance();
      _cache =
          jsonDecode(pref.getString(_prefKey) ?? "{}").cast<String, String>();
    } catch (e) {}
  }

  Future<void> _removeCache() async {
    try {
      _cache.remove(_courseId);
      _saveCache();
    } catch (e) {}
  }

  @override
  Future<TaskStatus> onError(String message) {
    _removeCache();
    return super.onError(message);
  }

  @override
  Future<TaskStatus> onErrorParameter(ErrorDialogParameter parameter) {
    _removeCache();
    return super.onErrorParameter(parameter);
  }
}
