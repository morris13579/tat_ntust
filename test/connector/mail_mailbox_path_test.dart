import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_test/flutter_test.dart';

/// wire 路徑解碼。這一組存在的理由是一個真的壞掉過的功能：
/// 「從回收筒搬回收件匣」永遠失敗。
void main() {
  String decode(String encoded) =>
      MailConnector.decodeMailboxPath(encoded, '/');

  test('目標是 INBOX 不會炸', () {
    // enough_mail 的 Mailbox 建構式看到名字解出來是 inbox 就往 flags 補一個
    // 旗標。先前傳的是 `const []`，那一補就丟 UnsupportedError，而例外被
    // moveToFolder 的 catch 吃掉，使用者只看到「操作失敗」。
    expect(decode('INBOX'), 'INBOX');
  });

  test('小寫的 inbox 也一樣（伺服器回什麼大小寫都不該炸）', () {
    expect(() => decode('inbox'), returnsNormally);
  });

  test('modified UTF-7 解得回中文資料夾名', () {
    // 回收筒 的 UTF-16BE 是 56DE 6536 7B52，base64 之後就是 Vt5lNntS。
    // 這正是連線器註解裡提到的那個字串。
    expect(decode('&Vt5lNntS-'), '回收筒');
  });

  test('純 ASCII 的自訂資料夾原樣回來', () {
    expect(decode('Archive'), 'Archive');
  });
}
