import 'package:flutter_app/src/enum/mail_folder_role.dart';
import 'package:flutter_test/flutter_test.dart';

/// 伺服器沒有 `SPECIAL-USE`，實測每個資料夾的 flags 都是空的，所以角色只能
/// 靠名字判斷。這份對照表錯了的後果是把信刪到別的資料夾去。
/// 名單來自真帳號的 `LIST ""` 實測，見 docs/WEBMAIL_IMAP.md §2.5。
void main() {
  test('Mail2000 原生的中文資料夾認得出來', () {
    expect(mailFolderRole('寄件備份匣'), MailFolderRole.sent);
    expect(mailFolderRole('草稿匣'), MailFolderRole.drafts);
    expect(mailFolderRole('回收筒'), MailFolderRole.trash);
    expect(mailFolderRole('廣告信匣'), MailFolderRole.junk);
  });

  test('其他郵件軟體建的英文資料夾也認得出來', () {
    // 同一個角色兩套名字並存：中文那套是 Mail2000 建的，英文那套是使用者
    // 接過 Apple Mail 之類才會出現。只認一套就會漏。
    expect(mailFolderRole('Sent Messages'), MailFolderRole.sent);
    expect(mailFolderRole('Drafts'), MailFolderRole.drafts);
    expect(mailFolderRole('Deleted Messages'), MailFolderRole.trash);
    expect(mailFolderRole('Junk'), MailFolderRole.junk);
    expect(mailFolderRole('Archive'), MailFolderRole.archive);
  });

  test('INBOX 不分大小寫', () {
    expect(mailFolderRole('INBOX'), MailFolderRole.inbox);
    expect(mailFolderRole('Inbox'), MailFolderRole.inbox);
  });

  test('認不出來的一律是 other，不要用猜的', () {
    // 「含有『草稿』兩個字就當草稿匣」這種猜法會把使用者自己建的
    // 「草稿備份」也認成草稿匣，然後把信搬進去。
    expect(mailFolderRole('草稿備份'), MailFolderRole.other);
    expect(mailFolderRole('Notes'), MailFolderRole.other);
    expect(mailFolderRole(''), MailFolderRole.other);
  });
}
