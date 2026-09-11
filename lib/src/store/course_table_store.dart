import 'dart:convert';

import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/key_value_store.dart';

/// 課表與學期清單的持久化。
///
/// `course_table_list` 是一個 StringList，每個元素各自是一份 CourseTableJson
/// 的 JSON，不是一整包 JSON 陣列；改格式會讀不到舊資料。
///
/// 學期清單是**純記憶體**的，不落地。
class CourseTableStore {
  static CourseTableStore instance =
      CourseTableStore(SharedPrefsKeyValueStore());

  static const courseTableListKey = 'course_table_list';

  final KeyValueStore _store;

  List<CourseTableJson> _tables = [];

  CourseTableStore(this._store);

  // ---- 課表 ----------------------------------------------------------------

  Future<void> load() async {
    final raw = await _store.readStringList(courseTableListKey);
    _tables = [];
    if (raw == null) return;
    for (final line in raw) {
      _tables.add(CourseTableJson.fromJson(json.decode(line)));
    }
  }

  Future<void> save() => _store.writeJsonList(courseTableListKey, _tables);

  Future<void> clear() async {
    _tables = [];
    await save();
  }

  /// 移除同一位學生同一學期的課表。
  ///
  /// 用 removeWhere：正向迴圈裡 removeAt 在有兩筆相符時會因索引位移漏掉第二筆。
  void remove(CourseTableJson table) {
    _tables.removeWhere((e) =>
        e.courseSemester == table.courseSemester &&
        e.studentId == table.studentId);
  }

  /// 以 (studentId, semester) 為主鍵放入，已存在就取代。
  void upsert(CourseTableJson table) {
    remove(table);
    _tables.add(table);
  }

  /// 依學號、再依學期新到舊排序後回傳。
  List<CourseTableJson> get tables {
    _tables.sort((a, b) {
      if (a.studentId == b.studentId) {
        return b.courseSemester
            .toString()
            .compareTo(a.courseSemester.toString());
      }
      return a.studentId.compareTo(b.studentId);
    });
    return _tables;
  }

  CourseTableJson? find(String studentId, SemesterJson? semester) {
    if (semester == null || studentId.isEmpty) return null;
    for (final table in _tables) {
      if (table.courseSemester == semester && table.studentId == studentId) {
        return table;
      }
    }
    return null;
  }

  // ---- 學期清單（純記憶體）--------------------------------------------------
  //
  // 刻意不持久化：每次冷啟動重新抓。

  List<SemesterJson> semesters = [];

  /// [semesters] 是不是完整的歷年清單。
  ///
  /// false 代表抓的當下成績系統沒答（逾時、子系統 session 未建立、或全新
  /// 安裝還沒抓過成績），清單裡只有當前學期。課表照樣能跑，但使用者下次
  /// 打開學期下拉選單時要再抓一次，否則選單會永遠只剩那一個學期。
  bool semestersComplete = false;

  void clearSemesters() {
    semesters = [];
    semestersComplete = false;
  }

  SemesterJson? semesterAt(int index) =>
      index >= 0 && index < semesters.length ? semesters[index] : null;
}
