import 'dart:convert';

import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/store/key_value_store.dart';
import 'package:flutter_app/src/store/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStore secure;
  late InMemoryKeyValueStore plain;
  late CredentialsStore repo;

  setUp(() {
    secure = InMemorySecureStore();
    plain = InMemoryKeyValueStore();
    repo = CredentialsStore(secure, plain);
  });

  String legacyJson({String account = 'B10902000', String password = 'pw'}) =>
      json.encode({
        'account': account,
        'password': password,
      });

  group('讀寫', () {
    test('存進 secure storage 而不是 SharedPreferences', () async {
      repo.setAccount('B10902000');
      repo.setPassword('p@ssw0rd');
      await repo.save();

      expect(secure.data[CredentialsStore.secureKey], contains('p@ssw0rd'));
      // 明文層只保留非機密的帳號鏡像。
      expect(plain.raw[CredentialsStore.accountMirrorKey], 'B10902000');
      expect(plain.raw.values.any((v) => v.toString().contains('p@ssw0rd')),
          isFalse);
    });

    test('沒有任何資料時回 absent', () async {
      expect(await repo.load(), CredentialsLoadResult.absent);
      expect(repo.hasCredentials, isFalse);
    });

    test('存過之後讀得回來', () async {
      repo.setAccount('B10902000');
      repo.setPassword('pw');
      await repo.save();

      final fresh = CredentialsStore(secure, plain);
      expect(await fresh.load(), CredentialsLoadResult.loaded);
      expect(fresh.account, 'B10902000');
      expect(fresh.password, 'pw');
      expect(fresh.hasCredentials, isTrue);
    });
  });

  group('從舊的 SharedPreferences 位置遷移', () {
    test('搬過去、讀回比對成功之後，明文那份就刪掉', () async {
      plain.raw[CredentialsStore.legacyKey] = legacyJson();

      expect(await repo.load(), CredentialsLoadResult.loaded);
      expect(repo.account, 'B10902000');
      expect(secure.data[CredentialsStore.secureKey], isNotNull);
      expect(plain.raw[CredentialsStore.legacyKey], isNull,
          reason: 'secure storage 已經有驗證過的副本，明文那份沒有理由留著');
    });

    test('已經遷移過的裝置，載入一次就會把殘留的明文那份刪掉', () async {
      // 清除殘留的明文不能只寫在遷移路徑上：已經遷移過的裝置（絕大多數升級
      // 上來的安裝）secure 讀得到就直接回，永遠不會再走那條路。
      secure.data[CredentialsStore.secureKey] = legacyJson();
      plain.raw[CredentialsStore.legacyKey] = legacyJson();

      expect(await repo.load(), CredentialsLoadResult.loaded);

      expect(plain.raw[CredentialsStore.legacyKey], isNull);
      expect(repo.password, 'pw', reason: '刪掉明文不影響讀到的憑證');
    });

    test('寫進 secure storage 但讀回來對不上時，明文那份一定要留著', () async {
      // 這時 secure storage 沒有可用的副本，刪掉就沒有第二份了。
      final dropping = _WriteDroppingSecureStore();
      final r = CredentialsStore(dropping, plain);
      plain.raw[CredentialsStore.legacyKey] = legacyJson();

      expect(await r.load(), CredentialsLoadResult.loaded);

      expect(r.password, 'pw', reason: '改用明文那份繼續跑，不要把使用者登出');
      expect(plain.raw[CredentialsStore.legacyKey], isNotNull);
    });

    test('secure storage 已經有資料時不再遷移', () async {
      secure.data[CredentialsStore.secureKey] =
          legacyJson(account: 'NEW', password: 'new-pw');
      plain.raw[CredentialsStore.legacyKey] =
          legacyJson(account: 'OLD', password: 'old-pw');

      await repo.load();
      expect(repo.account, 'NEW');
    });

    test('舊資料是空的就不算遷移', () async {
      plain.raw[CredentialsStore.legacyKey] =
          json.encode({'account': '', 'password': ''});

      expect(await repo.load(), CredentialsLoadResult.absent);
    });

    test('skipMigration 時不碰舊資料，供背景啟動使用', () async {
      // iOS 在鎖定狀態下被推播喚醒時 Keychain 不可寫，這時不要嘗試遷移，
      // 以免舊資料被讀走卻寫不進新位置。
      plain.raw[CredentialsStore.legacyKey] = legacyJson();

      expect(
          await repo.load(skipMigration: true), CredentialsLoadResult.absent);
      expect(secure.data[CredentialsStore.secureKey], isNull);
      expect(plain.raw[CredentialsStore.legacyKey], isNotNull);
    });
  });

  group('讀取失敗與「沒有憑證」必須分得開', () {
    test('Keystore 不可用時回 unavailable，不是 absent', () async {
      secure.throwOnRead = true;

      expect(await repo.load(), CredentialsLoadResult.unavailable);
    });

    test('讀取失敗（unavailable）時不刪明文那份', () async {
      // Keystore 暫時不可用時，明文那份可能是現場唯一的副本。
      plain.raw[CredentialsStore.legacyKey] = legacyJson();
      secure.throwOnRead = true;

      expect(await repo.load(), CredentialsLoadResult.unavailable);
      expect(plain.raw[CredentialsStore.legacyKey], isNotNull);
    });

    test('讀取失敗時不清除任何東西', () async {
      plain.raw[CredentialsStore.legacyKey] = legacyJson();
      secure.data[CredentialsStore.secureKey] = legacyJson();
      secure.throwOnRead = true;

      await repo.load();

      // Android 備份還原、iOS 鎖定狀態下背景喚醒都會走到這裡。
      // 清掉會讓使用者白白被登出，而且無法回退。
      expect(secure.data[CredentialsStore.secureKey], isNotNull);
      expect(plain.raw[CredentialsStore.legacyKey], isNotNull);
    });

    test('讀取失敗時保留記憶體內既有的憑證', () async {
      repo.setAccount('B10902000');
      repo.setPassword('pw');
      secure.throwOnRead = true;

      await repo.load();

      expect(repo.account, 'B10902000');
      expect(repo.hasCredentials, isTrue);
    });
  });

  group('clear', () {
    test('三個位置一起清掉', () async {
      repo.setAccount('B10902000');
      repo.setPassword('pw');
      await repo.save();
      plain.raw[CredentialsStore.legacyKey] = legacyJson();

      await repo.clear();

      expect(secure.data[CredentialsStore.secureKey], isNull);
      expect(plain.raw[CredentialsStore.legacyKey], isNull);
      expect(plain.raw[CredentialsStore.accountMirrorKey], isNull);
      expect(repo.hasCredentials, isFalse);
    });
  });
}

/// 寫得進去、讀回來卻是空的——模擬 secure storage 表面成功但實際沒存進去。
///
/// 用 [InMemorySecureStore.throwOnRead] 測不到這條路：`load()` 第一件事就是
/// read，會在還沒走到遷移之前就回 unavailable。
class _WriteDroppingSecureStore extends InMemorySecureStore {
  @override
  Future<void> write(String key, String value) async {}
}
