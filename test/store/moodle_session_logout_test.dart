import 'dart:convert';

import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/store/moodle_session_store.dart';
import 'package:flutter_app/src/store/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 登出必須連 SharedPreferences 的舊 key 一起刪。
///
/// 只刪 secure key 的話，`Model.logout()` 下一行的 `getInstance()` 會看到
/// token 是 null，從 legacyKey 把**前一位使用者的 token 遷移回 secure
/// storage**。當下看不出來（SessionCleaner 清的是記憶體裡的 static），
/// 下一次冷啟動 restoreToken 才會把它撈回來，而那時已經是另一個帳號了。
void main() {
  late InMemorySecureStore secure;
  late InMemoryKeyValueStore plain;
  late MoodleSessionStore repo;

  String tokenJson(String value) =>
      json.encode(MoodleTokenEntity('sig', value, 'priv').toJson());

  setUp(() {
    secure = InMemorySecureStore();
    plain = InMemoryKeyValueStore();
    repo = MoodleSessionStore(secure, plain);
  });

  test('clear 同時刪掉 secure 與 SharedPreferences 的舊 key', () async {
    await repo.save(MoodleTokenEntity('sig', 'a-token', 'priv'));
    plain.raw[MoodleSessionStore.legacyKey] = tokenJson('old-token');

    await repo.clear();

    expect(secure.data[MoodleSessionStore.secureKey], isNull);
    expect(plain.raw[MoodleSessionStore.legacyKey], isNull,
        reason: '舊 key 留著的話，下一次 getInstance 會把它遷移回 secure storage');
  });

  test('clear 之後再走一次遷移流程，撈不回任何東西', () async {
    // 這一條模擬 Model.logout()：clearMoodleToken() 之後緊接著 getInstance()。
    plain.raw[MoodleSessionStore.legacyKey] = tokenJson('old-token');
    await repo.load();
    await repo.clear();

    final migrated = await repo
        .migrateFrom(await plain.readString(MoodleSessionStore.legacyKey));

    expect(migrated, isFalse, reason: '舊 key 已經被刪，沒有東西可以遷移');
    expect(repo.token, isNull);
    expect(secure.data[MoodleSessionStore.secureKey], isNull);
  });

  test('遷移本身仍然可用，而且讀回比對成功之後會刪掉明文那份', () async {
    plain.raw[MoodleSessionStore.legacyKey] = tokenJson('legacy');

    final ok = await repo
        .migrateFrom(await plain.readString(MoodleSessionStore.legacyKey));

    expect(ok, isTrue);
    expect(repo.token?.token, 'legacy');
    expect(plain.raw[MoodleSessionStore.legacyKey], isNull,
        reason: 'secure storage 已經有驗證過的副本了');
  });

  test('已經遷移過的裝置，load 一次就會把殘留的明文 token 刪掉', () async {
    secure.data[MoodleSessionStore.secureKey] = tokenJson('secure');
    plain.raw[MoodleSessionStore.legacyKey] = tokenJson('legacy');

    final token = await repo.load();

    expect(token?.token, 'secure');
    expect(plain.raw[MoodleSessionStore.legacyKey], isNull);
  });

  test('寫進 secure storage 但讀回來對不上時，明文那份一定要留著', () async {
    final r = MoodleSessionStore(_WriteDroppingSecureStore(), plain);
    plain.raw[MoodleSessionStore.legacyKey] = tokenJson('legacy');

    final ok = await r
        .migrateFrom(await plain.readString(MoodleSessionStore.legacyKey));

    expect(ok, isTrue);
    expect(plain.raw[MoodleSessionStore.legacyKey], isNotNull,
        reason: '刪掉的話使用者就要重登 Moodle');
  });

  test('secure storage 讀取拋例外時不刪明文那份', () async {
    secure.data[MoodleSessionStore.secureKey] = tokenJson('secure');
    plain.raw[MoodleSessionStore.legacyKey] = tokenJson('legacy');
    secure.throwOnRead = true;

    expect(await repo.load(), isNull);
    expect(plain.raw[MoodleSessionStore.legacyKey], isNotNull);
  });
}

/// 寫得進去、讀回來卻是空的——模擬 secure storage 表面成功但實際沒存進去。
class _WriteDroppingSecureStore extends InMemorySecureStore {
  @override
  Future<void> write(String key, String value) async {}
}
