import 'dart:async';
import 'dart:convert';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/store/key_value_store.dart';

/// 一筆快取的位址與解碼方式。
///
/// [decode] 必填：出貨指令帶 `--obfuscate`，型別名會被改寫，靠
/// `T.toString()` 查表在 release 版永遠比對不中。
class CacheKey<T> {
  /// SharedPreferences 的 key。
  ///
  /// 一律以 `cache_` 開頭：登出時是用這個前綴掃出所有快取來清除的，
  /// 命名不符的 key 會在登出後殘留。沒有編譯期訊號，所以用 assert 擋。
  final String name;

  /// 同一個 key 底下的第幾筆。整包 blob 的形狀是 `{id: json}`。
  final String id;

  final T Function(dynamic json) decode;

  CacheKey(this.name, this.id, {required this.decode})
      : assert(name.startsWith('cache_'), 'cache key 必須以 cache_ 開頭，否則登出時不會被清除');
}

/// 離線快取的單一出口。
///
/// 壞資料分兩層處理：整包 blob 解不開就移除整個 key，單筆 decode 失敗
/// 只移除該筆再把其餘寫回。
class CacheStore {
  static CacheStore instance = CacheStore(SharedPrefsKeyValueStore());

  final KeyValueStore _store;

  /// 每個 `key.name` 上「排在最後面那一項」的完成訊號，用來把同一包 blob
  /// 的 read-modify-write 排成一列。佇列排空後會把該 name 移除。
  final Map<String, Future<void>> _pending = {};

  CacheStore(this._store);

  /// 讓同一個 [name] 上的 read-modify-write 依序執行。
  ///
  /// 每個操作都是「讀整包 blob → 改一筆 → 整包寫回」，而讀與寫之間至少隔著
  /// 兩次 await（[KeyValueStore] 每次都會 await
  /// `SharedPreferences.getInstance()`）。沒有這一層時，兩個並行寫入同一個
  /// name 的呼叫會各自拿到對方寫入「之前」的快照，後寫的那個把先寫的那一筆
  /// 整個蓋掉——不是覆寫同一筆，而是**別人的 id 憑空消失**。
  /// `cache_moodle_support`、`cache_course_extra`、`cache_moodle_score`
  /// 都是同一個 name 底下多個 id 並行寫入。
  Future<R> _serialized<R>(String name, Future<R> Function() action) {
    final previous = _pending[name];
    final done = Completer<void>();
    _pending[name] = done.future;

    final result = previous == null ? action() : previous.then((_) => action());
    return result.whenComplete(() {
      // 只有自己還是佇列尾端時才移除，否則會把後面排隊的人的接力棒丟掉。
      if (identical(_pending[name], done.future)) _pending.remove(name);
      done.complete();
    });
  }

  Future<T?> read<T>(CacheKey<T> key) => _serialized(key.name, () async {
        final raw = await _store.readString(key.name);
        if (raw == null) return null;

        Map<String, dynamic> obj;
        try {
          obj = Map<String, dynamic>.from(jsonDecode(raw));
        } catch (e) {
          // 整包 blob 壞掉，直接丟棄。
          await _store.remove(key.name);
          return null;
        }
        if (!obj.containsKey(key.id)) return null;

        try {
          return key.decode(obj[key.id]);
        } catch (e) {
          // 多半是升級前留下的舊格式。移除該筆即可，下次重新抓取，
          // 不要讓整個頁面因為讀快取而崩潰。
          obj.remove(key.id);
          await _store.writeString(key.name, jsonEncode(obj));
          return null;
        }
      });

  Future<void> write<T>(CacheKey<T> key, T value) =>
      _serialized(key.name, () async {
        try {
          final raw = await _store.readString(key.name) ?? "{}";
          final obj = Map<String, dynamic>.from(jsonDecode(raw));
          obj[key.id] = value;
          await _store.writeString(key.name, jsonEncode(obj));
        } catch (e, stack) {
          // 寫快取失敗不應該影響任務本身的結果。
          Log.eWithStack(e.toString(), stack);
        }
      });

  Future<void> removeEntry<T>(CacheKey<T> key) =>
      _serialized(key.name, () async {
        final raw = await _store.readString(key.name);
        if (raw == null) return;
        try {
          final obj = Map<String, dynamic>.from(jsonDecode(raw));
          obj.remove(key.id);
          await _store.writeString(key.name, jsonEncode(obj));
        } catch (e) {
          await _store.remove(key.name);
        }
      });

  /// 清掉所有快取。以 `cache_` 前綴比對，不是 contains("cache")。
  Future<void> clearAll() async {
    for (final k in await _store.keys()) {
      if (k.startsWith('cache_')) {
        // 一樣要排隊：登出時若有還沒落地的 write，直接 remove 會被那個
        // write 的整包寫回復活，等於登出後前一位使用者的資料還在。
        await _serialized(k, () => _store.remove(k));
      }
    }
  }
}
