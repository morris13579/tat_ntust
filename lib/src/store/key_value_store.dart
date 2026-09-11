import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 本機鍵值儲存的抽象層。
///
/// 所有 repository 共用這一層，[SharedPreferences] 的實作細節只出現在
/// [SharedPrefsKeyValueStore] 一個地方。
///
/// **key 名與 JSON 形狀是持久化契約**，不可更動：本專案曾因為格式變更
/// 丟過一次使用者資料。見 docs/ARCHITECTURE.md 的〈不可以改的東西〉。
///
/// **每個方法各自 await**（[SharedPrefsKeyValueStore] 每次都要
/// `await SharedPreferences.getInstance()`），所以「讀出來、改一改、寫回去」
/// 這種組合**不是原子的**：中間隔著至少兩次 await，另一個並行的呼叫可以插進來。
/// 需要原子性的呼叫端要自己排隊，`CacheStore` 就是這樣做的。
abstract class KeyValueStore {
  Future<String?> readString(String key);

  Future<void> writeString(String key, String value);

  Future<int?> readInt(String key);

  Future<void> writeInt(String key, int value);

  Future<bool?> readBool(String key);

  Future<void> writeBool(String key, bool value);

  Future<List<String>?> readStringList(String key);

  Future<void> writeStringList(String key, List<String> value);

  Future<void> remove(String key);

  Future<Set<String>> keys();

  /// 寫入一個可被 jsonEncode 的物件。
  Future<void> writeJson(String key, dynamic value) =>
      writeString(key, json.encode(value));

  /// 寫入一串物件，逐個 jsonEncode 後存成 StringList。
  ///
  /// 這是 course_table_list 與 course_semester_list 的既有格式：
  /// 一個 StringList，每個元素各自是一份 JSON，而不是一整包 JSON 陣列。
  Future<void> writeJsonList(String key, Iterable<dynamic> values) =>
      writeStringList(key, values.map(json.encode).toList());
}

class SharedPrefsKeyValueStore extends KeyValueStore {
  Future<SharedPreferences> get _pref => SharedPreferences.getInstance();

  @override
  Future<String?> readString(String key) async => (await _pref).getString(key);

  @override
  Future<void> writeString(String key, String value) async =>
      (await _pref).setString(key, value);

  @override
  Future<int?> readInt(String key) async => (await _pref).getInt(key);

  @override
  Future<void> writeInt(String key, int value) async =>
      (await _pref).setInt(key, value);

  @override
  Future<bool?> readBool(String key) async => (await _pref).getBool(key);

  @override
  Future<void> writeBool(String key, bool value) async =>
      (await _pref).setBool(key, value);

  @override
  Future<List<String>?> readStringList(String key) async =>
      (await _pref).getStringList(key);

  @override
  Future<void> writeStringList(String key, List<String> value) async =>
      (await _pref).setStringList(key, value);

  @override
  Future<void> remove(String key) async => (await _pref).remove(key);

  @override
  Future<Set<String>> keys() async => (await _pref).getKeys();
}

/// 測試用的記憶體實作。
class InMemoryKeyValueStore extends KeyValueStore {
  final Map<String, Object> _data = {};

  Map<String, Object> get raw => _data;

  T? _read<T>(String key) {
    final v = _data[key];
    return v is T ? v : null;
  }

  @override
  Future<String?> readString(String key) async => _read<String>(key);

  @override
  Future<void> writeString(String key, String value) async =>
      _data[key] = value;

  @override
  Future<int?> readInt(String key) async => _read<int>(key);

  @override
  Future<void> writeInt(String key, int value) async => _data[key] = value;

  @override
  Future<bool?> readBool(String key) async => _read<bool>(key);

  @override
  Future<void> writeBool(String key, bool value) async => _data[key] = value;

  @override
  Future<List<String>?> readStringList(String key) async =>
      _read<List<String>>(key);

  @override
  Future<void> writeStringList(String key, List<String> value) async =>
      _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Future<Set<String>> keys() async => _data.keys.toSet();
}
