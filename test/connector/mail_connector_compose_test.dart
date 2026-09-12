import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accountToAddress', () {
    test('學號補上信箱網域', () {
      expect(MailConnector.accountToAddress('B11000000'),
          'B11000000@mail.ntust.edu.tw');
    });

    test('已經是完整位址就原樣回', () {
      // 帳號欄位理論上只會是學號，但別人改過設定的裝置上什麼都可能有。
      expect(MailConnector.accountToAddress('someone@example.com'),
          'someone@example.com');
    });
  });

  group('inlineCidImages', () {
    /// 帶一張 1x1 PNG 內嵌圖的信。
    MimeMessage buildWithInlineImage({required String contentId}) {
      const png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final raw = 'Content-Type: multipart/related; boundary="b1"\r\n'
          '\r\n'
          '--b1\r\n'
          'Content-Type: text/html; charset="utf-8"\r\n'
          '\r\n'
          '<img src="cid:$contentId">\r\n'
          '--b1\r\n'
          'Content-Type: image/png\r\n'
          'Content-Transfer-Encoding: base64\r\n'
          'Content-ID: <$contentId>\r\n'
          '\r\n'
          '$png\r\n'
          '--b1--\r\n';
      return MimeMessage.parseFromData(Uint8List.fromList(latin1.encode(raw)));
    }

    test('cid: 換成 data: URI', () {
      // 不換的話 HtmlWidget 認不得 cid: scheme，Outlook 寄來的信會整片空白。
      final message = buildWithInlineImage(contentId: 'img1@example');
      final html = MailConnector.inlineCidImages(
          message, '<img src="cid:img1@example">');

      expect(html, contains('data:image/png;base64,'));
      expect(html, isNot(contains('cid:img1@example')));
    });

    test('Content-ID 的角括號要剝掉才對得上 src', () {
      // 標頭是 <foo@bar>，src 裡卻是不帶角括號的 foo@bar。
      final message = buildWithInlineImage(contentId: 'a@b');
      expect(
          message.allPartsFlat
              .any((p) => p.getHeaderValue('content-id') == '<a@b>'),
          isTrue);

      final html =
          MailConnector.inlineCidImages(message, '<img src="cid:a@b">');
      expect(html, contains('data:image/png;base64,'));
    });

    test('找不到對應的 part 就原樣留著，不要吃掉標籤', () {
      final message = buildWithInlineImage(contentId: 'img1@example');
      final html = MailConnector.inlineCidImages(
          message, '<img src="cid:missing@example">');

      expect(html, contains('cid:missing@example'));
    });
  });
}
