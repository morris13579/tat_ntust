import 'package:flutter_app/ui/pages/mail/mail_compose_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// 寫信頁的收件者解析與驗證。純函式，直接打。
void main() {
  group('parseAddresses', () {
    test('逗號與分號都算分隔', () {
      expect(MailComposePage.parseAddresses('a@x.com, b@y.com; c@z.com'),
          ['a@x.com', 'b@y.com', 'c@z.com']);
    });

    test('空白項被丟掉，尾逗號不會生出一個空位址', () {
      // 「a@x.com, 」是打到一半的常見狀態，不該變成兩個收件者。
      expect(MailComposePage.parseAddresses('a@x.com, '), ['a@x.com']);
      expect(MailComposePage.parseAddresses(' , ; '), isEmpty);
    });

    test('前後空白會被修掉', () {
      expect(MailComposePage.parseAddresses('  a@x.com  '), ['a@x.com']);
    });
  });

  group('looksLikeAddress', () {
    test('一般位址通過', () {
      expect(MailComposePage.looksLikeAddress('B11000000@mail.ntust.edu.tw'),
          isTrue);
      expect(
          MailComposePage.looksLikeAddress('a.b+c@sub.example.co.uk'), isTrue);
    });

    test('明顯不是位址的擋掉', () {
      expect(MailComposePage.looksLikeAddress('沒有小老鼠'), isFalse);
      expect(MailComposePage.looksLikeAddress('a@b'), isFalse);
      expect(MailComposePage.looksLikeAddress('a b@c.com'), isFalse);
      expect(MailComposePage.looksLikeAddress(''), isFalse);
    });

    test('不做嚴格的 RFC 驗證：合法但少見的寫法要放行', () {
      // 擋過頭比放過頭糟——使用者會遇到「這個位址明明可以寄卻寄不出去」。
      expect(MailComposePage.looksLikeAddress("o'brien@example.com"), isTrue);
      expect(
          MailComposePage.looksLikeAddress('a_b-c@example-host.com'), isTrue);
    });
  });
}
