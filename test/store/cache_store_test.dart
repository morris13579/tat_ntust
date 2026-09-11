import 'dart:convert';

import 'package:flutter_app/src/store/cache_store.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

CacheKey<String> _key(String id) =>
    CacheKey<String>('cache_demo', id, decode: (json) => json as String);

void main() {
  late InMemoryKeyValueStore store;
  late CacheStore cache;

  setUp(() {
    store = InMemoryKeyValueStore();
    cache = CacheStore(store);
  });

  group('讀寫', () {
    test('寫進去讀得回來，blob 形狀是 {id: value}', () async {
      await cache.write(_key('a'), 'hello');

      expect(jsonDecode(store.raw['cache_demo'] as String), {'a': 'hello'});
      expect(await cache.read(_key('a')), 'hello');
    });

    test('同一個 key 底下可以放多筆，互不影響', () async {
      await cache.write(_key('a'), 'A');
      await cache.write(_key('b'), 'B');

      expect(await cache.read(_key('a')), 'A');
      expect(await cache.read(_key('b')), 'B');
    });

    test('key 不存在或 id 不存在都回 null', () async {
      expect(await cache.read(_key('a')), isNull);
      await cache.write(_key('a'), 'A');
      expect(await cache.read(_key('nope')), isNull);
    });
  });

  group('壞資料處理', () {
    test('整包 blob 解不開時移除整個 key', () async {
      store.raw['cache_demo'] = '這不是 json';

      expect(await cache.read(_key('a')), isNull);
      expect(store.raw.containsKey('cache_demo'), isFalse);
    });

    test('單筆 decode 失敗時只移除該筆，其餘保留', () async {
      store.raw['cache_demo'] = jsonEncode({'bad': 123, 'good': 'ok'});
      // decode 是 `json as String`，數字會拋。
      expect(await cache.read(_key('bad')), isNull);

      final remain = jsonDecode(store.raw['cache_demo'] as String) as Map;
      expect(remain.containsKey('bad'), isFalse, reason: '壞掉的那筆要被移除');
      expect(remain['good'], 'ok', reason: '其他 id 不受影響');
      expect(await cache.read(_key('good')), 'ok');
    });

    test('寫入時底層拋例外不會傳播出去', () async {
      store.raw['cache_demo'] = '壞掉的 json';
      // write 會先讀舊 blob，解不開時走 catch，不該讓呼叫端看到例外。
      await expectLater(cache.write(_key('a'), 'A'), completes);
    });
  });

  group('removeEntry 與 clearAll', () {
    test('removeEntry 只拿掉指定的那一筆', () async {
      await cache.write(_key('a'), 'A');
      await cache.write(_key('b'), 'B');

      await cache.removeEntry(_key('a'));

      expect(await cache.read(_key('a')), isNull);
      expect(await cache.read(_key('b')), 'B');
    });

    test('clearAll 以 cache_ 前綴比對，不碰其他 key', () async {
      await cache.write(_key('a'), 'A');
      store.raw['cache_moodle_support'] = jsonEncode({'CS101': 'x'});
      store.raw['user_data'] = '{}';
      store.raw['setting'] = '{}';
      // 這個 key 含有 "cache" 子字串但不是快取，比對必須用 startsWith。
      store.raw['my_cached_preference'] = 'keep me';

      await cache.clearAll();

      expect(store.raw.containsKey('cache_demo'), isFalse);
      expect(store.raw.containsKey('cache_moodle_support'), isFalse);
      expect(store.raw.containsKey('user_data'), isTrue);
      expect(store.raw.containsKey('setting'), isTrue);
      expect(store.raw.containsKey('my_cached_preference'), isTrue,
          reason: 'contains("cache") 會誤刪這一個，startsWith("cache_") 不會');
    });
  });

  group('CacheKey 的命名契約', () {
    test('不以 cache_ 開頭時 assert 失敗', () {
      // 登出是用 cache_ 前綴掃出所有快取來清除的，命名不符會在登出後殘留，
      // 而且這條契約沒有任何編譯期訊號。
      expect(
        () =>
            CacheKey<String>('moodle_support', 'a', decode: (j) => j as String),
        throwsA(isA<AssertionError>()),
      );
    });

    test('以 cache_ 開頭時正常建立', () {
      expect(
        CacheKey<String>('cache_ok', 'a', decode: (j) => j as String).name,
        'cache_ok',
      );
    });
  });
}
