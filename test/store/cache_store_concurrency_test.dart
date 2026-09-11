import 'dart:convert';

import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

CacheKey<String> _key(String id) =>
    CacheKey<String>('cache_demo', id, decode: (json) => json as String);

/// 在每一次讀寫之間多插一個 event loop 的縫。
///
/// 真機上 [SharedPrefsKeyValueStore] 的每個方法都要先 `await
/// SharedPreferences.getInstance()`，「讀 blob」與「寫回 blob」之間本來就有
/// 排程點。這個 fake 把那道縫變成明確的前提，就算日後有人把 in-memory 版改成
/// 同步回傳，這幾個測試也還是在測它們該測的東西。
class _GappyStore extends InMemoryKeyValueStore {
  @override
  Future<String?> readString(String key) async {
    await Future<void>.delayed(Duration.zero);
    return super.readString(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    await Future<void>.delayed(Duration.zero);
    return super.writeString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await Future<void>.delayed(Duration.zero);
    return super.remove(key);
  }
}

/// 同一個 key name 底下的並行 read-modify-write。
///
/// [CacheStore] 的三個方法都是「讀整包 blob → 改一筆 → 整包寫回」，而經由
/// [KeyValueStore] 之後讀與寫各自 await：沒有排隊的話，後寫的那一方拿的是
/// 對方寫入之前的快照，會把對方那一筆整個抹掉。
///
/// CacheStore 因此對每個 key name 排一條佇列，這一組測試釘住它。
void main() {
  late _GappyStore store;
  late CacheStore cache;

  setUp(() {
    store = _GappyStore();
    cache = CacheStore(store);
  });

  Map<String, dynamic> blob() =>
      jsonDecode(store.raw['cache_demo'] as String) as Map<String, dynamic>;

  test('兩個並行 write 打同一個 key name 時兩筆都要留著', () async {
    // 沒有排隊的話結果會是 {"b":"B"}，'a' 憑空消失。
    await Future.wait([
      cache.write(_key('a'), 'A'),
      cache.write(_key('b'), 'B'),
    ]);

    expect(blob(), {'a': 'A', 'b': 'B'});
  });

  test('大量並行 write 一筆都不能掉', () async {
    // cache_moodle_support 由四個 Moodle 分頁共寫，只靠 courseId
    // 分筆；掉一筆的代價是下次要多兩次 POST 才拿得回 Moodle 內部 id。
    await Future.wait([
      for (var i = 0; i < 20; i++) cache.write(_key('id$i'), 'v$i'),
    ]);

    expect(blob().length, 20);
    for (var i = 0; i < 20; i++) {
      expect(await cache.read(_key('id$i')), 'v$i');
    }
  });

  test('removeEntry 與 write 並行時，被移除的那一筆不會被復活', () async {
    await cache.write(_key('a'), 'A');

    // 沒有排隊的話兩邊都讀到 {"a":"A"}，removeEntry 寫回 {}，write 再寫回
    // {"a":"A","b":"B"}，等於刪除完全沒發生。
    await Future.wait([
      cache.removeEntry(_key('a')),
      cache.write(_key('b'), 'B'),
    ]);

    expect(blob(), {'b': 'B'});
  });

  test('read 的壞資料修復與並行 write 不會互相覆蓋', () async {
    store.raw['cache_demo'] = jsonEncode({'bad': 123, 'good': 'ok'});

    // read('bad') 會 decode 失敗，順手把 'bad' 移掉再把其餘寫回——那也是一次
    // read-modify-write，同樣要排隊，否則不是新寫的 'c' 不見，就是 'bad' 復活。
    final reading = cache.read(_key('bad'));
    final writing = cache.write(_key('c'), 'C');

    expect(await reading, isNull);
    await writing;
    expect(blob(), {'good': 'ok', 'c': 'C'});
  });

  test('clearAll 不會被還沒落地的 write 復活', () async {
    store.raw['cache_demo'] = jsonEncode({'a': 'A'});

    // 登出的實際樣子：按下登出時還有任務的快取寫入在飛。沒有排隊的話
    // remove 先跑、write 再把整包 blob 寫回去，前一位使用者的資料就留在裝置上。
    final pending = cache.write(_key('b'), 'B');
    await cache.clearAll();
    await pending;

    expect(store.raw.containsKey('cache_demo'), isFalse);
  });

  test('不同 key name 各自一條佇列，互不影響', () async {
    // 佇列是 per-name 的：cache_demo 的寫入不該卡住 cache_other。
    final other =
        CacheKey<String>('cache_other', 'x', decode: (json) => json as String);

    await Future.wait([
      cache.write(_key('a'), 'A'),
      cache.write(other, 'X'),
    ]);

    expect(await cache.read(_key('a')), 'A');
    expect(await cache.read(other), 'X');
  });
}
