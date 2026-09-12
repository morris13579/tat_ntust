import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_test/flutter_test.dart';

/// quoted-printable + Big5 的內文解碼——真機上「內文整個亂碼」的那個 bug。
///
/// `enough_mail` 的 QP 解碼是 charset-unaware 的：它只把**連續的** `=XX` 湊成
/// 一組交給 charset codec，但 Big5 的 trail byte 落在 0x40–0x7E 時是可列印
/// ASCII，QP 不會編碼它，於是解碼器只拿到孤立的 lead byte。
///
/// fixture 是一封真的校內信（多國語言辦公室的公告），去識別化後只留
/// multipart/alternative 那一段；承辦人信箱已遮蔽。它的結構是
/// `text/plain(base64)` + `text/html(quoted-printable)`，兩個 part 都是 big5，
/// 正好把「會壞的」與「不會壞的」放在同一封信裡。
void main() {
  late MimeMessage message;

  setUpAll(() {
    message = MimeMessage.parseFromData(
        File('test/fixtures/mail/big5_multipart.eml').readAsBytesSync());
  });

  /// U+FFFD。解碼失敗時塞進來的替換字元。
  const replacement = '�';

  test('先確認這份 fixture 真的踩得到 enough_mail 的缺陷', () {
    // 這條不是在測我們的程式，是在確認 fixture 沒有失效。哪天上游修好了，
    // 這條會變紅，那時就可以把 MailConnector 裡的繞道拿掉。
    final upstream = message.decodeTextHtmlPart()!;

    expect(upstream, contains(replacement),
        reason: 'enough_mail 若已修好 QP + Big5，就不需要再自己解碼了');
  });

  test('自己解的 HTML part 沒有整段爛掉', () {
    final html = MailConnector.decodeBestTextPart(message, 'text/html')!;
    final upstream = message.decodeTextHtmlPart()!;

    final ours = replacement.allMatches(html).length;
    final theirs = replacement.allMatches(upstream).length;
    expect(ours, lessThan(theirs ~/ 10), reason: '替換字元數量必須從數百降到個位數');

    // 剩下的替換字元全在 <style> 的 mso-level-text，那是 Word 的 Symbol 字型
    // 單 byte 項目符號，本來就不是合法 Big5，不影響可見內容。
    for (final m in replacement.allMatches(html)) {
      final around = html.substring((m.start - 30).clamp(0, m.start), m.start);
      expect(around, contains('mso-level-text'), reason: '可見內容裡不該再有解不開的字');
    }
  });

  test('中文真的解得出來，不是只有替換字元變少', () {
    final html = MailConnector.decodeBestTextPart(message, 'text/html')!;
    final upstream = message.decodeTextHtmlPart()!;
    final cjk = RegExp(r'[一-鿿]');

    expect(cjk.allMatches(html).length,
        greaterThan(cjk.allMatches(upstream).length));
    // 這一串在上游那版是斷掉的（「新」的 lead byte 被吃掉變成 "?s細明體"）。
    expect(html, contains('新細明體'));
    expect(html, contains('臺科大雙語教育推動辦公室'));
  });

  test('base64 的 text/plain 也解得對', () {
    final plain = MailConnector.decodeBestTextPart(message, 'text/plain')!;

    expect(plain, isNot(contains(replacement)));
    expect(plain, contains('臺科大雙語教育推動辦公室'));
  });

  test('base64 的 Big5 內文也走自己的解碼，不是交給上游', () {
    // 先前這裡是「base64 走原路就對」。那個判斷只在 QP 那個缺陷的範圍內成立
    // ——後來發現 enough_convert 的 Big5 表本身少了 14 個碼位（含常用的
    // 「告」），base64 一樣中。位元組由 Python 的 big5 codec 產生。
    final mail = MimeMessage.parseFromText('''
Content-Type: text/plain; charset="big5"
Content-Transfer-Encoding: base64

plWm7KZQvsehR6W7s0KkvadppnCkVaFBvdC41L5coUM=
'''
        .replaceAll('\n', '\r\n'));

    final plain = MailConnector.decodeBestTextPart(mail, 'text/plain')!;

    expect(plain, contains('本處公告如下'));
    expect(plain, isNot(contains(replacement)));
    // 對照組：上游那條路在同一份輸入上仍然是壞的。
    expect(mail.decodeTextPlainPart(), contains(replacement));
  });

  test('找不到那個 media type 時回 null', () {
    expect(MailConnector.decodeBestTextPart(message, 'text/calendar'), isNull);
  });
}
