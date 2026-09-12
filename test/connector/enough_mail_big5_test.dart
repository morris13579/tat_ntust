import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';

/// `enough_mail` 解不解得開 Big5——docs/WEBMAIL_IMAP.md 的門檻 B。
///
/// 這一份不是在測 TAT 的程式碼，是在測相依套件的能力，因為整個信箱功能的
/// 解碼策略押在它身上：解不開就得改用 `charset_converter` 走原生轉碼，
/// `MailConnector` 的寫法會跟著不一樣。所以它要擋在 connector 前面。
///
/// fixture 取自臺科信箱的真實信件，但只留 Subject 的 encoded-word 與一段
/// Big5 內文；收件者、Received、Message-ID 這些含個人資訊的標頭都沒有寫進去。
/// 主旨是**跨行折疊成兩段 encoded-word** 的，那正是天真的解碼器會斷掉的地方。
void main() {
  final fixture = File('test/fixtures/mail/big5_subject.eml');
  final expected = File('test/fixtures/mail/big5_subject.expected.txt')
      .readAsStringSync()
      .trim();

  test('折疊成兩段的 Big5 encoded-word 主旨解得開', () {
    final message = MimeMessage.parseFromData(fixture.readAsBytesSync());

    expect(message.decodeSubject(), expected);
  });

  test('MailCodec.decodeHeader 直接吃原始標頭值也解得開', () {
    // 走 MimeMessage 以外的路徑再驗一次：真正做事的是 MailCodec，
    // 未來若只拿 ENVELOPE 而不是整封信，走的就是這一條。
    final raw = message0Subject(fixture);

    expect(MailCodec.decodeHeader(raw), expected);
  });

  test('Big5 內文解得出中文，而且沒有替換字元', () {
    final message = MimeMessage.parseFromData(fixture.readAsBytesSync());

    final body = message.decodeTextPlainPart();

    expect(body, isNotNull);
    // U+FFFD 是解碼失敗時塞進來的替換字元，出現就代表 charset 認錯了。
    expect(body, isNot(contains('�')));
    expect(RegExp(r'[一-鿿]').hasMatch(body!), isTrue,
        reason: '內文應該要有中文字，沒有就是整段解成了亂碼');
  });
}

/// 從 fixture 撈出未經解碼的 `Subject:` 值（含折疊的第二行）。
String message0Subject(File fixture) {
  final lines = fixture.readAsLinesSync();
  final start = lines.indexWhere((l) => l.startsWith('Subject:'));
  final buffer = StringBuffer(lines[start].substring('Subject:'.length).trim());
  for (var i = start + 1; i < lines.length; i++) {
    if (!lines[i].startsWith(' ') && !lines[i].startsWith('\t')) break;
    buffer.write(lines[i].trim());
  }
  return buffer.toString();
}
