import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/model/mail/mail_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// 寄出去的信長什麼樣子。**不寄信，只把 MIME 組出來看。**
///
/// 「收到的信與寄出時顯示的完全不同」的成因：根 MessageBuilder 沒有指定
/// contentType，enough_mail 看到「沒有 contentType 但有子 part」就補成
/// multipart/mixed——兩份內文變成並列，收件端顯示純文字那一份。
void main() {
  const from = MailAddress(null, 'me@mail.ntust.edu.tw');
  late Directory temp;

  setUpAll(() => temp = Directory.systemTemp.createTempSync('tat-mime'));
  tearDownAll(() => temp.deleteSync(recursive: true));

  Future<String> render(MailDraft draft) async =>
      (await MailConnector.buildMimeMessage(draft, from)).renderMessage();

  const draft = MailDraft(
    to: ['you@example.com'],
    subject: '主旨',
    body: '<p>超文字</p>',
  );

  test('沒有附件時根是 multipart/alternative，不是 mixed', () async {
    final mime = await render(draft);

    expect(mime, contains('multipart/alternative'));
    expect(mime, isNot(contains('multipart/mixed')));
  });

  test('純文字排在 HTML 前面——收件端挑最後一個看得懂的', () async {
    // RFC 2046 §5.1.4。順序反了，收件端就顯示純文字那一份。
    final mime = await render(draft);

    expect(mime.indexOf('text/plain'), lessThan(mime.indexOf('text/html')));
  });

  test('兩份內文都在，HTML 沒有被換成純文字', () async {
    final mime = await render(draft);

    expect(mime, contains('text/plain'));
    expect(mime, contains('text/html'));
  });

  test('內文 part 是 quoted-printable，不是 7bit', () async {
    // 純英文內文會被判成 7bit，而 enough_mail 的 wrapText() 會在 7bit 下硬
    // 換行——長網址與 data: URI 會被從中間切斷。
    final mime = await render(const MailDraft(
      to: ['you@example.com'],
      body: '<p>plain english body</p>',
    ));

    expect('quoted-printable'.allMatches(mime).length, greaterThanOrEqualTo(2));
    expect(mime, isNot(contains('Content-Transfer-Encoding: 7bit')));
  });

  test('有附件時外層 mixed、內文那一段仍然是 alternative', () async {
    final file = File('${temp.path}/a.txt')..writeAsStringSync('hi');
    final mime = await render(MailDraft(
      to: ['you@example.com'],
      body: '<p>超文字</p>',
      attachments: [file],
    ));

    expect(mime.indexOf('multipart/mixed'),
        lessThan(mime.indexOf('multipart/alternative')));
    expect(mime.indexOf('text/plain'), lessThan(mime.indexOf('text/html')));
    expect(mime, contains('a.txt'));
  });

  test('副本進標頭、密件副本不進', () async {
    // 密件副本寫進標頭的話收件者互相看得到，那正好是它要避免的事。
    final mime = await render(const MailDraft(
      to: ['you@example.com'],
      cc: ['cc@example.com'],
      bcc: ['bcc@example.com'],
      body: '<p>x</p>',
    ));

    expect(mime, contains('cc@example.com'));
    expect(mime, isNot(contains('bcc@example.com')));
  });
}
