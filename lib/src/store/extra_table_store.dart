import 'dart:convert';

import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/store/key_value_store.dart';

/// 一份「不是我這學期實際課表」的課表：模擬排課的草稿，或掃進來的別人課表。
///
/// [id] 是穩定的識別，切換器與管理頁都靠它指到同一份；不能用 (學號, 學期) 當
/// 主鍵——同一個人同一學期可以有好幾份草稿。
class ExtraTable {
  ExtraTable({
    required this.id,
    required this.label,
    required this.table,
    required this.savedAt,
    this.payload,
  });

  final String id;

  /// 畫面上的名字：草稿是「115-1 加退選草稿」，他人課表是學號。
  String label;

  CourseTableJson table;

  /// 草稿是最後編輯時間，他人課表是匯入時間。
  DateTime savedAt;

  /// 他人課表才有：QR 的原始碼，是這份資料的真相來源。留著就能隨時重新還原成
  /// 最新的課名與教室，[table] 只是免得每次開啟都重打網路的快取。
  final String? payload;

  factory ExtraTable.fromJson(Map<String, dynamic> json) => ExtraTable(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        table: CourseTableJson.fromJson(
            Map<String, dynamic>.from(json['table'] as Map)),
        savedAt: DateTime.fromMillisecondsSinceEpoch(
            (json['savedAt'] as num?)?.toInt() ?? 0),
        payload: json['payload'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'table': table.toJson(),
        'savedAt': savedAt.millisecondsSinceEpoch,
        if (payload != null) 'payload': payload,
      };
}

/// 模擬課表（草稿）與他人課表的持久化。
///
/// **刻意不塞進 [CourseTableStore]**：那一份以 (學號, 學期) 為主鍵，而且整包
/// 直接餵給收藏課表的 UI；把草稿或別人的課表放進去會污染那份清單，也會讓
/// 「我的課表」多出幾筆不是我的東西。
///
/// 兩份清單各自一個 key，格式跟 `course_table_list` 一樣是 StringList，
/// 每個元素各自是一份 JSON。
class ExtraTableStore {
  static ExtraTableStore instance = ExtraTableStore(SharedPrefsKeyValueStore());

  /// 模擬排課的草稿。
  static const draftListKey = 'draft_course_table_list';

  /// 掃描匯入的他人課表。
  static const sharedListKey = 'shared_course_table_list';

  final KeyValueStore _store;

  List<ExtraTable> _drafts = [];
  List<ExtraTable> _shared = [];

  ExtraTableStore(this._store);

  /// 新到舊：切換器與管理頁都是最近的排前面。
  List<ExtraTable> get drafts => _sorted(_drafts);

  List<ExtraTable> get shared => _sorted(_shared);

  static List<ExtraTable> _sorted(List<ExtraTable> tables) {
    final sorted = [...tables]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return sorted;
  }

  Future<void> load() async {
    _drafts = await _read(draftListKey);
    _shared = await _read(sharedListKey);
  }

  Future<List<ExtraTable>> _read(String key) async {
    final raw = await _store.readStringList(key);
    if (raw == null) return [];
    final tables = <ExtraTable>[];
    for (final line in raw) {
      // 一筆壞掉不該讓整份清單消失。
      try {
        tables.add(ExtraTable.fromJson(
            Map<String, dynamic>.from(json.decode(line) as Map)));
      } catch (_) {
        continue;
      }
    }
    return tables;
  }

  Future<void> saveDrafts() => _store.writeJsonList(draftListKey, _drafts);

  Future<void> saveShared() => _store.writeJsonList(sharedListKey, _shared);

  ExtraTable? findDraft(String id) => _find(_drafts, id);

  ExtraTable? findShared(String id) => _find(_shared, id);

  static ExtraTable? _find(List<ExtraTable> tables, String id) {
    for (final table in tables) {
      if (table.id == id) return table;
    }
    return null;
  }

  Future<void> upsertDraft(ExtraTable table) async {
    _drafts
      ..removeWhere((e) => e.id == table.id)
      ..add(table);
    await saveDrafts();
  }

  Future<void> upsertShared(ExtraTable table) async {
    _shared
      ..removeWhere((e) => e.id == table.id)
      ..add(table);
    await saveShared();
  }

  Future<void> removeDraft(String id) async {
    _drafts.removeWhere((e) => e.id == id);
    await saveDrafts();
  }

  Future<void> removeShared(String id) async {
    _shared.removeWhere((e) => e.id == id);
    await saveShared();
  }

  /// 登出時連同兩份一起清掉：草稿是這位使用者排的，他人課表是他掃進來的，
  /// 下一位使用者不該看到任何一份。
  Future<void> clear() async {
    _drafts = [];
    _shared = [];
    await saveDrafts();
    await saveShared();
  }
}
