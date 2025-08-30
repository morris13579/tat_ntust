import 'dart:convert';

import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/entity/moodle_token_entity.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/model/setting/setting_json.dart';
import 'package:flutter_app/src/model/userdata/user_data_json.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_task.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

//flutter packages pub run build_runner build 創建Json
//flutter packages pub run build_runner build --delete-conflicting-outputs
class Model {
  static final Model instance = Model();
  static String userDataJsonKey = "user_data";

  //----------List----------//
  static String courseTableJsonKey = "course_table_list";
  static String courseSemesterJsonKey = "course_semester_list";

  //----------Object----------//
  static String scoreCreditJsonKey = "score_credit";
  static String settingJsonKey = "setting";

  static String agreeContributorKey = "agree_privacy_policy";
  UserDataJson _userData = UserDataJson();
  List<CourseTableJson> _courseTableList = [];
  List<SemesterJson> _courseSemesterList = [];
  ScoreRankJson _score = ScoreRankJson();
  SettingJson _setting = SettingJson();
  final Map<String, bool> _firstRun = {};
  static String appCheckUpdate = "app_check_update";
  DefaultCacheManager cacheManager = DefaultCacheManager();

  bool get autoCheckAppUpdate {
    return _setting.other.autoCheckAppUpdate;
  }

  Future<bool> getAgreeContributor() async {
    var pref = await SharedPreferences.getInstance();
    return pref.getBool(agreeContributorKey) ?? false;
  }

  Future<void> setAgreeContributor(bool value) async {
    var pref = await SharedPreferences.getInstance();
    pref.setBool(agreeContributorKey, value);
  }

  //timeOut seconds
  Future<bool> getFirstUse(String key, {int? timeOut}) async {
    if (timeOut != null) {
      int millsTimeOut = timeOut * 1000;
      String wKey = "${key}_timestamp";
      int now = DateTime.now().millisecondsSinceEpoch;
      int? before = await _readInt(wKey);
      if (before != null && before > now) {
        //Already Use
        return false;
      } else {
        await _writeInt(wKey, now + millsTimeOut);
      }
    }
    if (!_firstRun.containsKey(key)) {
      _firstRun[key] = true;
    }
    return _firstRun[key]!;
  }

  void setAlreadyUse(String key) {
    _firstRun[key] = false;
  }

  void setFirstUse(String key, bool value) {
    String wKey = "firstUse$key";
    _writeInt(wKey, 0);
    _firstRun[key] = value;
  }

  //--------------------UserDataJson--------------------//
  Future<void> saveUserData() async {
    await _save(userDataJsonKey, _userData);
  }

  Future<void> clearUserData() async {
    _userData = UserDataJson();
    await saveUserData();
  }

  Future<void> loadUserData() async {
    String? readJson;
    readJson = (await _readString(userDataJsonKey));
    _userData = (readJson != null)
        ? UserDataJson.fromJson(json.decode(readJson))
        : UserDataJson();
  }

  void setAccount(String account) {
    _userData.account = account;
  }

  String getAccount() {
    return _userData.account;
  }

  String getWebMailPassword() {
    return _userData.webMailPassword;
  }

  void setWebMailPassword(String password) {
    _userData.webMailPassword = password;
  }

  void setPassword(String password) {
    _userData.password = password;
  }

  String getPassword() {
    return _userData.password;
  }

  UserDataJson getUserData() {
    return _userData;
  }

  //--------------------List<CourseTableJson>--------------------//
  Future<void> saveCourseTableList() async {
    await _save(courseTableJsonKey, _courseTableList);
  }

  Future<void> clearCourseTableList() async {
    _courseTableList = [];
    await saveCourseTableList();
  }

  Future<void> loadCourseTableList() async {
    List<String>? readJsonList = [];
    readJsonList = (await _readStringList(courseTableJsonKey));
    _courseTableList = [];
    if (readJsonList != null) {
      for (String readJson in readJsonList) {
        _courseTableList.add(CourseTableJson.fromJson(json.decode(readJson)));
      }
    }
  }

  String? getCourseNameByCourseId(String courseId) {
    //利用課程id取得課程資訊
    String? name;
    for (CourseTableJson courseDetail in _courseTableList) {
      name = courseDetail.getCourseNameByCourseId(courseId);
      if (name != null) {
        return name;
      }
    }
    return null;
  }

  void removeCourseTable(CourseTableJson addCourseTable) {
    List<CourseTableJson> tableList = _courseTableList;
    for (int i = 0; i < tableList.length; i++) {
      CourseTableJson table = tableList[i];
      if (table.courseSemester == addCourseTable.courseSemester &&
          table.studentId == addCourseTable.studentId) {
        tableList.removeAt(i);
      }
    }
  }

  void addCourseTable(CourseTableJson addCourseTable) {
    List<CourseTableJson> tableList = _courseTableList;
    removeCourseTable(addCourseTable);
    tableList.add(addCourseTable);
  }

  List<CourseTableJson> getCourseTableList() {
    _courseTableList.sort((a, b) {
      if (a.studentId == b.studentId) {
        return b.courseSemester
            .toString()
            .compareTo(a.courseSemester.toString());
      }
      return a.studentId.compareTo(b.studentId);
    });
    return _courseTableList;
  }

  CourseTableJson? getCourseTable(
      String studentId, SemesterJson? courseSemester) {
    List<CourseTableJson> tableList = _courseTableList;
    if (courseSemester == null || studentId.isEmpty) {
      return null;
    }
    for (int i = 0; i < tableList.length; i++) {
      CourseTableJson table = tableList[i];
      if (table.courseSemester == courseSemester &&
          table.studentId == studentId) {
        return table;
      }
    }
    return null;
  }

  //--------------------ScoreJson--------------------//
  Future<void> saveScore() async {
    await _save(scoreCreditJsonKey, _score);
  }

  void setScore(ScoreRankJson value) {
    _score = value;
  }

  Future<void> clearScore() async {
    _score = ScoreRankJson();
    await saveScore();
  }

  ScoreRankJson getScore() {
    return _score;
  }

  Future<void> loadScore() async {
    String? readJson;
    readJson = await _readString(scoreCreditJsonKey);
    _score = (readJson != null)
        ? ScoreRankJson.fromJson(json.decode(readJson))
        : ScoreRankJson();
  }

  //--------------------SettingJson--------------------//
  Future<void> saveSetting() async {
    await _save(settingJsonKey, _setting);
  }

  Future<void> clearSetting() async {
    _setting = SettingJson();
    await saveSetting();
  }

  Future<void> loadSetting() async {
    String? readJson;
    readJson = await _readString(settingJsonKey);
    _setting = (readJson != null)
        ? SettingJson.fromJson(json.decode(readJson))
        : SettingJson();
  }

  //--------------------CourseSettingJson--------------------//
  Future<void> saveCourseSetting() async {
    await saveSetting();
  }

  Future<void> clearCourseSetting() async {
    _setting.course = CourseSettingJson(info: CourseTableJson());
    await saveCourseSetting();
  }

  void setCourseSetting(CourseSettingJson value) {
    _setting.course = value;
  }

  CourseSettingJson getCourseSetting() {
    return _setting.course;
  }

  //--------------------OtherSettingJson--------------------//
  Future<void> saveOtherSetting() async {
    await saveSetting();
  }

  Future<void> clearOtherSetting() async {
    _setting.other = OtherSettingJson();
    await saveOtherSetting();
  }

  void setOtherSetting(OtherSettingJson value) {
    _setting.other = value;
  }

  OtherSettingJson getOtherSetting() {
    return _setting.other;
  }

  //--------------------List<SemesterJson>--------------------//
  Future<void> clearSemesterJsonList() async {
    _courseSemesterList = [];
  }

  Future<void> saveSemesterJsonList() async {
    _save(courseSemesterJsonKey, _courseSemesterList);
  }

  Future<void> loadSemesterJsonList() async {
    List<String>? readJsonList = [];
    readJsonList = await _readStringList(courseSemesterJsonKey);
    _courseSemesterList = [];
    if (readJsonList != null) {
      for (String readJson in readJsonList) {
        _courseSemesterList.add(SemesterJson.fromJson(json.decode(readJson)));
      }
    }
  }

  void setSemesterJsonList(List<SemesterJson> value) {
    _courseSemesterList = value;
  }

  SemesterJson? getSemesterJsonItem(int index) {
    if (_courseSemesterList.length > index) {
      return _courseSemesterList[index];
    } else {
      return null;
    }
  }

  List<SemesterJson> getSemesterList() {
    return _courseSemesterList;
  }

  List<String> getSemesterListString() {
    List<String> stringList = [];
    for (SemesterJson value in _courseSemesterList) {
      stringList.add("${value.year}-${value.semester}");
    }
    return stringList;
  }

  //--------------------App Version--------------------//
  Future<String> getVersion() async {
    return (await _readString("version")) ?? "";
  }

  Future<void> setVersion(String version) async {
    await _writeString("version", version); //寫入目前版本
  }

  //--------------------Moodle Token--------------------//
  Future<MoodleTokenEntity?> getMoodleToken() async {
    var json = await _readString("moodle_token");
    if(json == null) {
      return null;
    }

    return MoodleTokenEntity.fromJson(jsonDecode(json));
  }

  Future<void> setMoodleToken(MoodleTokenEntity token) async {
    await _writeString("moodle_token", jsonEncode(token));
  }

  Future<void> loadMoodleToken() async {
    var token = await getMoodleToken();
    if(token == null) {
      return;
    }

    MoodleTask.isLogin = true;
    MoodleWebApiConnector.wsToken = token.token;
    MoodleWebApiConnector.privateToken = token.privateToken;
  }

  Future<void> clearMoodleToken() async {
    var pref = await SharedPreferences.getInstance();
    await pref.remove("moodle_token");
  }


  Future<bool> clearAll() async {
    var pref = await SharedPreferences.getInstance();
    return pref.clear();
  }

  Future<bool> getInstance() async {
    bool catchError = false;
    try {
      await DioConnector.instance.init();
      await loadUserData();
    } catch (e) {
      catchError = true;
      await clearUserData();
    }
    try {
      await loadCourseTableList();
    } catch (e) {
      catchError = true;
      await clearCourseTableList();
    }
    try {
      await loadSetting();
    } catch (e) {
      catchError = true;
      await clearSetting();
    }
    try {
      await loadSemesterJsonList();
    } catch (e) {
      catchError = true;
      await clearSemesterJsonList();
    }
    try {
      await loadScore();
    } catch (e) {
      catchError = true;
      await clearScore();
    }
    try {
      await loadScore();
    } catch (e) {
      catchError = true;
      await clearScore();
    }
    try {
      //await loadMoodleToken();
    } catch (e) {
      catchError = true;
      await clearMoodleToken();
    }
    return catchError;
  }

  Future<void> logout() async {
    await clearUserData();
    await clearSemesterJsonList();
    await clearCourseTableList();
    await clearCourseSetting();
    await clearScore();
    await clearMoodleToken();
    DioConnector.instance.deleteCookies();
    await cacheManager.emptyCache(); //clears all data in cache.
    await getInstance();
    var pref = await SharedPreferences.getInstance();
    for (var i in pref.getKeys()) {
      if (i.contains("cache")) {
        pref.remove(i);
      }
    }
  }

  Future<void> _save(String key, dynamic saveObj) async {
    try {
      await _saveJsonList(key, saveObj);
    } catch (e) {
      await _saveJson(key, saveObj);
    }
  }

  Future<void> _saveJson(String key, dynamic saveObj) async {
    await _writeString(key, json.encode(saveObj));
  }

  Future<void> _saveJsonList(String key, dynamic saveObj) async {
    List<String> jsonList = [];
    for (dynamic obj in saveObj) {
      jsonList.add(json.encode(obj));
    }
    await _writeStringList(key, jsonList);
  }

  Future<void> _clear(String key) async {
    await _clearSetting(key);
  }

  //基本讀寫

  Future<void> _writeString(String key, String value) async {
    var pref = await SharedPreferences.getInstance();
    await pref.setString(key, value);
  }

  Future<void> _writeInt(String key, int value) async {
    var pref = await SharedPreferences.getInstance();
    await pref.setInt(key, value);
  }

  Future<int?> _readInt(String key) async {
    var pref = await SharedPreferences.getInstance();
    return pref.getInt(key);
  }

  Future<void> _writeStringList(String key, List<String> value) async {
    var pref = await SharedPreferences.getInstance();
    await pref.setStringList(key, value);
  }

  Future<String?> _readString(String key) async {
    var pref = await SharedPreferences.getInstance();
    return pref.getString(key);
  }

  Future<List<String>?> _readStringList(String key) async {
    var pref = await SharedPreferences.getInstance();
    return pref.getStringList(key);
  }

  Future<void> _clearSetting(String key) async {
    var pref = await SharedPreferences.getInstance();
    await pref.remove(key);
  }
}
