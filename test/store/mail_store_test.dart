import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:flutter_app/src/model/mail/mail_folder_json.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_app/src/store/mail_store.dart';
import 'package:flutter_test/flutter_test.dart';

MailMessageJson message(int uid,
        {bool seen = false, List<String> to = const []}) =>
    MailMessageJson(uid: uid, subject: '主旨 $uid', seen: seen, to: to);

/// 信件快取的行為契約。這裡測的是 [InMemoryMailStore]，正式的 sqflite 實作
/// 要平台通道跑不了；兩者共用同一個介面，契約寫在這裡。
void main() {
  late MailStore store;

  setUp(() => store = InMemoryMailStore());

  test('沒存過的資料夾回空清單，不是 null 也不是拋例外', () async {
    expect(await store.readMessages('INBOX'), isEmpty);
  });

  test('replaceMessages 是換掉不是合併', () async {
    // 伺服器沒有 CONDSTORE，我們拿不到差異，只能以這次抓回來的那批為準。
    // 合併的話伺服器端已刪除的信會永遠留在本機。
    await store.replaceMessages('INBOX', [message(1), message(2)]);
    await store.replaceMessages('INBOX', [message(2)]);

    expect((await store.readMessages('INBOX')).map((m) => m.uid), [2]);
  });

  test('不同資料夾互不影響', () async {
    // UID 只在資料夾內唯一，兩個資料夾各有 uid=1 是正常的。
    await store.replaceMessages('INBOX', [message(1)]);
    await store.replaceMessages('寄件備份匣', [message(1), message(2)]);

    expect((await store.readMessages('INBOX')).length, 1);
    expect((await store.readMessages('寄件備份匣')).length, 2);
  });

  test('updateSeen 只動那一列', () async {
    await store.replaceMessages('INBOX', [message(1), message(2)]);

    await store.updateSeen('INBOX', 2, seen: true);

    final list = await store.readMessages('INBOX');
    expect(list.firstWhere((m) => m.uid == 1).seen, isFalse);
    expect(list.firstWhere((m) => m.uid == 2).seen, isTrue);
  });

  test('deleteMessage 只刪那一封', () async {
    await store.replaceMessages('INBOX', [message(1), message(2)]);

    await store.deleteMessage('INBOX', 1);

    expect((await store.readMessages('INBOX')).map((m) => m.uid), [2]);
  });

  test('收件者清單存得回來', () async {
    // 全部回覆要用它。存成一個字串欄位，分隔符不能是逗號——顯示名稱裡常有。
    await store.replaceMessages('INBOX', [
      message(1, to: ['a@x.com', 'b@y.com']),
    ]);

    expect(
        (await store.readMessages('INBOX')).single.to, ['a@x.com', 'b@y.com']);
  });

  test('資料夾順序保留', () async {
    await store.replaceFolders(const [
      MailFolderJson(path: 'INBOX', name: 'INBOX', role: MailFolderRole.inbox),
      MailFolderJson(path: '寄件備份匣', name: '寄件備份匣', role: MailFolderRole.sent),
    ]);

    expect((await store.readFolders()).map((f) => f.path), ['INBOX', '寄件備份匣']);
  });

  test('資料夾的計數存得回來', () async {
    // 計數是後來才加的欄位。加欄位而沒有升 DB 版本的話，既有安裝會停在舊
    // schema，這裡的 insert 會整批失敗而且只留下一行 log。
    await store.replaceFolders(const [
      MailFolderJson(
          path: 'INBOX',
          name: 'INBOX',
          role: MailFolderRole.inbox,
          messageCount: 4366,
          unreadCount: 2918),
    ]);

    final folder = (await store.readFolders()).single;
    expect(folder.messageCount, 4366);
    expect(folder.unreadCount, 2918);
    expect(folder.hasCount, isTrue);
  });

  test('沒問到計數時 hasCount 為假，畫面才不會顯示 0 騙人', () {
    const folder = MailFolderJson(path: 'X', name: 'X');

    expect(folder.hasCount, isFalse);
    expect(folder.messageCount, -1);
  });

  test('clear 兩張表都要清', () async {
    // 漏一張就是換帳號後 B 看得到 A 的東西。
    await store.replaceMessages('INBOX', [message(1)]);
    await store.replaceFolders(const [
      MailFolderJson(path: 'INBOX', name: 'INBOX', role: MailFolderRole.inbox),
    ]);

    await store.clear();

    expect(await store.readMessages('INBOX'), isEmpty);
    expect(await store.readFolders(), isEmpty);
  });
}
