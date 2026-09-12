import 'package:flutter_app/src/model/mail/mail_contact.dart';
import 'package:flutter_app/src/store/mail_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 通訊紀錄。`InMemoryMailStore` 與 sqflite 那一份要同一套語意——測試打的是
/// 前者，語意的註解與 UPSERT 的 SQL 寫在同一個介面上。
void main() {
  late InMemoryMailStore store;

  setUp(() => store = InMemoryMailStore());

  test('位址一律小寫：同一個人用 Prof@ 和 prof@ 不該變成兩筆', () async {
    await store.rememberContacts([
      const MailContact(email: 'Prof@mail.ntust.edu.tw', name: '老師'),
      const MailContact(email: 'prof@mail.ntust.edu.tw'),
    ]);

    expect(store.contacts.length, 1);
    expect(store.contacts.keys.single, 'prof@mail.ntust.edu.tw');
  });

  test('名字是空的不要蓋掉已經存好的名字', () async {
    // 很多系統信只有位址沒有顯示名稱，讓它覆蓋已知的名字是退步。
    await store
        .rememberContacts([const MailContact(email: 'a@x.com', name: '教務處')]);
    await store.rememberContacts([const MailContact(email: 'a@x.com')]);

    expect((await store.searchContacts('a@x')).single.name, '教務處');
  });

  test('sentCount 是累加的，不是被換掉的', () async {
    // 收信時也會 remember 同一個位址（sentCount 0）。那一趟把計數歸零的話
    // 「寄過的人排前面」就永遠不會發生。
    await store
        .rememberContacts([const MailContact(email: 'a@x.com', sentCount: 1)]);
    await store
        .rememberContacts([const MailContact(email: 'a@x.com', sentCount: 1)]);
    await store.rememberContacts([const MailContact(email: 'a@x.com')]);

    expect((await store.searchContacts('a@x')).single.sentCount, 2);
  });

  test('lastSeen 只往前不往後', () async {
    await store.rememberContacts(
        [const MailContact(email: 'a@x.com', lastSeenMillis: 200)]);
    await store.rememberContacts(
        [const MailContact(email: 'a@x.com', lastSeenMillis: 100)]);

    expect((await store.searchContacts('a@x')).single.lastSeenMillis, 200);
  });

  test('寄過的人排在只寄信來過的人前面，再同分才看時間', () async {
    await store.rememberContacts([
      const MailContact(email: 'news@x.com', lastSeenMillis: 900),
      const MailContact(email: 'ta@x.com', lastSeenMillis: 100, sentCount: 1),
      const MailContact(email: 'old@x.com', lastSeenMillis: 50),
    ]);

    expect((await store.searchContacts('@x.com')).map((c) => c.email),
        ['ta@x.com', 'news@x.com', 'old@x.com']);
  });

  test('名字也比對得到，而且不分大小寫', () async {
    await store.rememberContacts(
        [const MailContact(email: 'a@x.com', name: 'Academic Affairs')]);

    expect((await store.searchContacts('ACADEMIC')).single.email, 'a@x.com');
  });

  test('limit 會擋住', () async {
    await store.rememberContacts([
      for (var i = 0; i < 20; i++) MailContact(email: 'a$i@x.com'),
    ]);

    expect((await store.searchContacts('@x.com', limit: 6)).length, 6);
  });

  test('空位址直接丟掉，不要生出一筆沒有 email 的聯絡人', () async {
    await store.rememberContacts([const MailContact(email: '  ')]);

    expect(store.contacts, isEmpty);
  });

  test('登出要連通訊紀錄一起清——留著等於換帳號後 B 看得到 A 的聯絡人', () async {
    await store.rememberContacts([const MailContact(email: 'a@x.com')]);

    await store.clear();

    expect(await store.searchContacts('a@x'), isEmpty);
  });

  test('沒有名字的顯示成只有位址，不要印出一個空括號', () {
    expect(const MailContact(email: 'a@x.com').label, 'a@x.com');
    expect(const MailContact(email: 'a@x.com', name: '甲').label, '甲 <a@x.com>');
  });
}
