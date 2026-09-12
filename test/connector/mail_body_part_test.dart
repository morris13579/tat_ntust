import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_test/flutter_test.dart';

MimeMessage parse(String raw) =>
    MimeMessage.parseFromText(raw.replaceAll('\n', '\r\n'));

/// 挑「哪個 part 才是內文」。
///
/// 先前是「掃 allPartsFlat，取最後一個符合 mediaType 的」。那份清單是整棵樹的
/// 展開，夾帶信件（message/rfc822）自己的內文與附件都在裡面，而且排在真正的
/// 內文後面——Google Meet 的邀請信正是這個形狀，於是內文顯示不出來。
void main() {
  test('單層信：就是那一個 part', () {
    final m = parse('''
Content-Type: text/plain; charset="utf-8"

內文
''');

    expect(MailConnector.decodeBestTextPart(m, 'text/plain')?.trim(), '內文');
  });

  test('multipart/alternative：兩種都拿得到', () {
    final m = parse('''
Content-Type: multipart/alternative; boundary="b"

--b
Content-Type: text/plain; charset="utf-8"

純文字
--b
Content-Type: text/html; charset="utf-8"

<p>超文字</p>
--b--
''');

    expect(MailConnector.decodeBestTextPart(m, 'text/plain')?.trim(), '純文字');
    expect(
        MailConnector.decodeBestTextPart(m, 'text/html')?.trim(), '<p>超文字</p>');
  });

  test('夾帶另一封信時，取的是外層的內文而不是夾帶物的', () {
    // 這就是先前壞掉的形狀：message/rfc822 的內文排在真正的內文後面，
    // 「取最後一個」會挑到它。
    final m = parse('''
Content-Type: multipart/mixed; boundary="b"

--b
Content-Type: text/plain; charset="utf-8"

我才是內文
--b
Content-Type: message/rfc822

Content-Type: text/plain; charset="utf-8"

我是被夾帶的另一封信
--b--
''');

    expect(MailConnector.decodeBestTextPart(m, 'text/plain')?.trim(), '我才是內文');
  });

  test('附件不算內文', () {
    final m = parse('''
Content-Type: multipart/mixed; boundary="b"

--b
Content-Type: text/plain; charset="utf-8"

我才是內文
--b
Content-Type: text/plain; charset="utf-8"
Content-Disposition: attachment; filename="note.txt"

我是附件
--b--
''');

    expect(MailConnector.decodeBestTextPart(m, 'text/plain')?.trim(), '我才是內文');
  });

  test('Google Meet 那種形狀：mixed 包 alternative 再夾 text/calendar', () {
    final m = parse('''
Content-Type: multipart/mixed; boundary="outer"

--outer
Content-Type: multipart/alternative; boundary="inner"

--inner
Content-Type: text/plain; charset="utf-8"

你被邀請參加會議
--inner
Content-Type: text/html; charset="utf-8"

<p>你被邀請參加會議</p>
--inner--
--outer
Content-Type: text/calendar; method=REQUEST; charset="utf-8"

BEGIN:VCALENDAR
END:VCALENDAR
--outer--
''');

    expect(MailConnector.decodeBestTextPart(m, 'text/html')?.trim(),
        '<p>你被邀請參加會議</p>');
    expect(
        MailConnector.decodeBestTextPart(m, 'text/plain')?.trim(), '你被邀請參加會議');
  });

  test('找不到那個 media type 時回 null', () {
    final m = parse('''
Content-Type: text/plain; charset="utf-8"

只有純文字
''');

    expect(MailConnector.decodeBestTextPart(m, 'text/html'), isNull);
  });
}
