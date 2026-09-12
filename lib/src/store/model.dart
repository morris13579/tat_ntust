import 'dart:convert';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/model/setting/setting_json.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_app/src/store/course_table_store.dart';
import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/store/extra_table_store.dart';
import 'package:flutter_app/src/store/moodle_session_store.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/store/score_store.dart';

//flutter packages pub run build_runner build 創建Json
//flutter packages pub run build_runner build --delete-conflicting-outputs
class Model {
  static final Model instance = Model();

  /// 所有本機讀寫的唯一出口。測試可換成 [InMemoryKeyValueStore]。
  KeyValueStore store = SharedPrefsKeyValueStore();
  static String userDataJsonKey = "user_data";

  //----------List----------//
  static String courseTableJsonKey = "course_table_list";
  static String courseSemesterJsonKey = "course_semester_list";

  //----------Object----------//
  static String scoreCreditJsonKey = "score_credit";
  static String settingJsonKey = "setting";

  static String agreeContributorKey = "agree_privacy_policy";
  SettingJson _setting = SettingJson();
  final Map<String, bool> _firstRun = {};
  late final DefaultCacheManager cacheManager = DefaultCacheManager();

  Future<bool> getAgreeContributor() async =>
      await store.readBool(agreeContributorKey) ?? false;

  Future<void> setAgreeContributor(bool value) =>
      store.writeBool(agreeContributorKey, value);

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

  //--------------------UserDataJson--------------------//
  // 實作在 CredentialsStore（底層是 Keystore / Keychain）。

  Future<void> saveUserData() => CredentialsStore.instance.save();

  Future<void> clearUserData() => CredentialsStore.instance.clear();

  Future<void> loadUserData() async {
    await CredentialsStore.instance.load();
  }

  void setAccount(String account) =>
      CredentialsStore.instance.setAccount(account);

  String getAccount() => CredentialsStore.instance.account;

  void setPassword(String password) =>
      CredentialsStore.instance.setPassword(password);

  String getPassword() => CredentialsStore.instance.password;

  void setMailPassword(String password) =>
      CredentialsStore.instance.setMailPassword(password);

  String getMailPassword() => CredentialsStore.instance.mailPassword;

  //--------------------List<CourseTableJson>--------------------//
  // 實作在 CourseTableStore 與 ScoreStore，這裡只剩轉呼叫。

  Future<void> saveCourseTableList() => CourseTableStore.instance.save();

  Future<void> clearCourseTableList() => CourseTableStore.instance.clear();

  Future<void> loadCourseTableList() => CourseTableStore.instance.load();

  void removeCourseTable(CourseTableJson table) =>
      CourseTableStore.instance.remove(table);

  void addCourseTable(CourseTableJson table) =>
      CourseTableStore.instance.upsert(table);

  List<CourseTableJson> getCourseTableList() =>
      CourseTableStore.instance.tables;

  CourseTableJson? getCourseTable(String studentId, SemesterJson? semester) =>
      CourseTableStore.instance.find(studentId, semester);

  //--------------------ScoreJson--------------------//
  Future<void> saveScore() => ScoreStore.instance.save();

  void setScore(ScoreRankJson value) => ScoreStore.instance.score = value;

  Future<void> clearScore() => ScoreStore.instance.clear();

  ScoreRankJson getScore() => ScoreStore.instance.score;

  Future<void> loadScore() => ScoreStore.instance.load();

  //--------------------SettingJson--------------------//
  Future<void> saveSetting() async {
    // setting 存成單一 JSON 物件，不是 StringList。
    await store.writeJson(settingJsonKey, _setting);
  }

  Future<void> loadSetting() async {
    final readJson = await _readString(settingJsonKey);
    _setting = (readJson != null) ? _decodeSetting(readJson) : SettingJson();
  }

  /// 解析 setting blob；整包解不出來時改成逐段搶救。
  ///
  /// setting 是唯一沒有伺服器副本的純本地資料。[SettingJson.fromJson] 是
  /// 全有全無的——`course` 裡任何一個欄位型別不對，`other` 的 `lang` 與
  /// `useMoodleWebApi` 就一起陪葬，所以整包失敗時逐段解，只讓壞掉的
  /// 那一段退回預設。
  ///
  /// 只有連 json.decode 都過不了才會拋出去，由 [_loadOrLog] 記錄；
  /// 磁碟上的原始位元組不會被動到。
  SettingJson _decodeSetting(String readJson) {
    final decoded = json.decode(readJson);
    if (decoded is! Map<String, dynamic>) {
      // 拋出去而不是靜默吃掉，才會在 log 裡留下紀錄。訊息刻意不帶 blob 內容。
      throw const FormatException('setting blob 不是 JSON 物件');
    }
    try {
      return SettingJson.fromJson(decoded);
    } catch (e, stack) {
      Log.eWithStack('setting 整包解析失敗，改為逐段搶救: $e', stack);
      return SettingJson(
        course: _decodeSection(decoded['course'], CourseSettingJson.fromJson),
        other: _decodeSection(decoded['other'], OtherSettingJson.fromJson),
      );
    }
  }

  /// 解析 setting 的其中一段，失敗回 null 讓 [SettingJson] 自己補預設值。
  T? _decodeSection<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      return fromJson(raw);
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return null;
    }
  }

  //--------------------CourseSettingJson--------------------//
  Future<void> saveCourseSetting() async {
    await saveSetting();
  }

  Future<void> clearCourseSetting() async {
    _setting.course = CourseSettingJson(info: CourseTableJson());
    await saveCourseSetting();
  }

  CourseSettingJson getCourseSetting() {
    return _setting.course;
  }

  //--------------------OtherSettingJson--------------------//
  Future<void> saveOtherSetting() async {
    await saveSetting();
  }

  void setOtherSetting(OtherSettingJson value) {
    _setting.other = value;
  }

  OtherSettingJson getOtherSetting() {
    return _setting.other;
  }

  //--------------------List<SemesterJson>--------------------//
  Future<void> clearSemesterJsonList() async =>
      CourseTableStore.instance.clearSemesters();

  /// 學期清單不落地，載入等於清空記憶體清單。
  Future<void> loadSemesterJsonList() async =>
      CourseTableStore.instance.clearSemesters();

  /// [complete] 為 false 代表這份清單只有當前學期，歷年來源沒有貢獻。
  /// 見 [CourseTableStore.semestersComplete]。
  void setSemesterJsonList(List<SemesterJson> value, {bool complete = true}) {
    CourseTableStore.instance.semesters = value;
    CourseTableStore.instance.semestersComplete = complete;
  }

  bool isSemesterListComplete() => CourseTableStore.instance.semestersComplete;

  SemesterJson? getSemesterJsonItem(int index) =>
      CourseTableStore.instance.semesterAt(index);

  List<SemesterJson> getSemesterList() => CourseTableStore.instance.semesters;

  //--------------------App Version--------------------//
  Future<String> getVersion() async {
    return (await _readString("version")) ?? "";
  }

  Future<void> setVersion(String version) async {
    await _writeString("version", version); //寫入目前版本
  }

  //--------------------Moodle Token--------------------//
  Future<MoodleTokenEntity?> getMoodleToken() async =>
      MoodleSessionStore.instance.token ??
      await MoodleSessionStore.instance.load();

  Future<void> setMoodleToken(MoodleTokenEntity token) =>
      MoodleSessionStore.instance.save(token);

  Future<void> clearMoodleToken() => MoodleSessionStore.instance.clear();

  Future<bool> getInstance() async {
    bool catchError = false;

    // 憑證這一條腿的失敗語意與其他不同：讀不到可能只是 Keystore 暫時
    // 不可用（Android 備份還原、iOS 鎖定狀態下被背景推播喚醒），
    // 這時清掉會讓使用者白白被登出且無法回退。
    final credentials = await CredentialsStore.instance.load();
    if (credentials == CredentialsLoadResult.unavailable) {
      catchError = true;
    }

    // 舊版 moodle_token 存在 SharedPreferences；讀回比對成功之後
    // MoodleSessionStore 才會把明文那份刪掉。
    if (MoodleSessionStore.instance.token == null) {
      try {
        if (await MoodleSessionStore.instance.load() == null) {
          final legacy = await store.readString(MoodleSessionStore.legacyKey);
          await MoodleSessionStore.instance.migrateFrom(legacy);
        }
      } catch (e, stack) {
        catchError = true;
        Log.eWithStack(e.toString(), stack);
      }
    }

    catchError |= await _loadOrLog(loadCourseTableList);
    catchError |= await _loadOrLog(loadSetting);
    catchError |= await _loadOrLog(loadSemesterJsonList);
    catchError |= await _loadOrLog(loadScore);
    return catchError;
  }

  /// 載入失敗只記錄並回報，**絕對不回寫**。
  ///
  /// 不要在 catch 裡呼叫 clearX()：那會把空物件存回磁碟，一個位元組壞掉
  /// 原始 blob 就在開機當下被永久覆蓋。setting（語言、自動更新、目前顯示
  /// 的課表）在伺服器上沒有副本，蓋掉就真的沒了。clearX 自己也會寫磁碟、
  /// 也會拋，例外逃出 getInstance 會讓 runApp 不被呼叫，使用者卡在 splash。
  ///
  /// 記憶體退回預設值讓 App 照常開起來，磁碟原封不動；使用者下次改設定、
  /// 重抓課表或成績時正常的 saveX 就會覆蓋掉，等於自己痊癒。
  ///
  /// 四條腿在 load 拋出後的記憶體狀態都已經是安全的，這是前提，不要拿掉：
  /// - loadSetting 例外時 _setting 保留上一份可用值，而且它自己還會先逐段
  ///   搶救，見 [_decodeSetting]。
  /// - ScoreStore.load 是單一指派，拋出時 score 維持原值。
  /// - CourseTableStore.load 先清成空清單再逐行解析，拋出時留下已成功解析
  ///   的前綴；注意之後的 saveCourseTableList 會把沒解析到的那幾行寫掉。
  /// - loadSemesterJsonList 只清記憶體清單，本來就不會拋。
  Future<bool> _loadOrLog(Future<void> Function() load) async {
    try {
      await load();
      return false;
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
      return true;
    }
  }

  Future<void> logout() async {
    await clearUserData();
    await clearSemesterJsonList();
    await clearCourseTableList();
    // 草稿與掃進來的他人課表也是這位使用者的，換人登入不該看得到。
    await ExtraTableStore.instance.clear();
    await clearCourseSetting();
    await clearScore();
    await clearMoodleToken();
    await cacheManager.emptyCache(); //clears all data in cache.
    await getInstance();
    // 以 cache_ 前綴比對，不要用 contains("cache")：後者會誤刪任何含該
    // 子字串的 key。
    for (final k in await store.keys()) {
      if (k.startsWith("cache_")) {
        await store.remove(k);
      }
    }
  }

  Future<void> _writeString(String key, String value) =>
      store.writeString(key, value);

  Future<void> _writeInt(String key, int value) => store.writeInt(key, value);

  Future<int?> _readInt(String key) => store.readInt(key);

  Future<String?> _readString(String key) => store.readString(key);
}
