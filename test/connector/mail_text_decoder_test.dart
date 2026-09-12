import 'package:enough_convert/enough_convert.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_app/src/util/mail_text_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// 補過洞的 Big5 解碼與 RFC 2047 標頭解碼。
///
/// **所有位元組都是 Python 的 big5 codec 產的**（權威來源），不是
/// `Big5Codec` 的 encoder——它不是解碼的忠實反函式（見
/// [MailTextDecoder.big5Patch] 的註解），拿它產輸入會測到假的東西。
void main() {
  // 真實信件的主旨。「告」= A7 69，正是漏掉的那 14 個碼位之一。
  const subject = '【電資學院EMI獎勵公告】115-1申請培力英文檢定獎勵即日起開放申請';

  group('Big5 補丁', () {
    test('「告」解得出來', () {
      expect(MailTextDecoder.big5([0xA7, 0x69]), '告');
    });

    test('十四個補回來的碼位一個都不能少', () {
      MailTextDecoder.big5Patch.forEach((key, expected) {
        final decoded = MailTextDecoder.big5([key >> 8, key & 0xFF]);
        expect(decoded, expected,
            reason: '0x${key.toRadixString(16)} 應為 $expected');
      });
    });

    test('沒漏的碼位照樣正確，補丁不會蓋到別人', () {
      // 這幾個 enough_convert 本來就對，補丁不該動它們。
      expect(MailTextDecoder.big5([0xA4, 0xBD]), '公');
      expect(MailTextDecoder.big5([0xB9, 0x71]), '電');
      expect(MailTextDecoder.big5([0xBE, 0xC7]), '學');
      expect(MailTextDecoder.big5([0xC0, 0x79]), '勵');
    });

    test('補丁的字夾在一般字中間也接得起來', () {
      // 「公告」= A4 BD A7 69：前一個走 codec、後一個走補丁，接縫不能掉字。
      expect(MailTextDecoder.big5([0xA4, 0xBD, 0xA7, 0x69]), '公告');
    });

    test('trail byte 落在 lead 範圍時不會從字中間重新斷詞', () {
      // 「勵」= C0 79；79 不在 lead 範圍。「資」= B8 EA，EA 落在 lead 範圍
      // （0xA1–0xF9），一次只前進一格的實作會把它當成下一個字的開頭。
      expect(MailTextDecoder.big5([0xB8, 0xEA, 0xBE, 0xC7]), '資學');
    });

    test('ASCII 照原樣穿過去', () {
      expect(MailTextDecoder.big5([0x45, 0x4D, 0x49]), 'EMI');
    });

    test('落單的位元組不會讓整段解碼失敗', () {
      // Word 的 <style> 裡有 Symbol 字型的單 byte 項目符號，本來就不是合法
      // Big5。為它整封失敗不划算，allowInvalid 讓它變成替換字元就好。
      expect(() => MailTextDecoder.big5([0xB7]), returnsNormally);
    });

    test('空輸入回空字串', () {
      expect(MailTextDecoder.big5(const []), '');
    });
  });

  group('RFC 2047 標頭', () {
    test('整段 B 編碼', () {
      expect(
          MailTextDecoder.header(
              '=?big5?B?oWm5cbjqvsewfEVNSbz6wHmkvadpoWoxMTUtMaXTvdCw9qRPrV6k5cDLqXe8+sB5p1mk6bBftn2p8aXTvdA=?='),
          subject);
    });

    test('切在「告」中間的兩段 B 編碼要先接位元組再解', () {
      // 折行時一個 Big5 字被切成兩半是真實信件裡就有的事。逐段解會在接縫處
      // 吐替換字元。
      const raw =
          '=?big5?B?oWm5cbjqvsewfEVNSbz6wHmkvac=?=\r\n =?big5?B?aaFqMTE1LTGl073QsPakT61epOXAy6l3vPrAeadZpOmwX7Z9qfGl073Q?=';

      expect(MailTextDecoder.header(raw), subject);
    });

    test('Q 編碼', () {
      expect(
          MailTextDecoder.header(
              '=?big5?Q?=A1i=B9q=B8=EA=BE=C7=B0|EMI=BC=FA=C0y=A4=BD=A7i=A1j115-1=A5=D3=BD=D0=B0=F6=A4O=AD^=A4=E5=C0=CB=A9w=BC=FA=C0y=A7Y=A4=E9=B0=5F=B6}=A9=F1=A5=D3=BD=D0?='),
          subject);
    });

    test('encoded-word 與普通文字之間的空白要留著', () {
      expect(MailTextDecoder.header('Re: =?big5?B?p2k=?= end'), 'Re: 告 end');
    });

    test('相鄰 encoded-word 之間的折行空白要吃掉', () {
      // RFC 2047 §6.2：那是折行留下來的，不是內容。
      expect(
          MailTextDecoder.header('=?big5?B?p2k=?=\r\n =?big5?B?p2k=?='), '告告');
    });

    test('UTF-8 的 encoded-word 也要能解', () {
      expect(MailTextDecoder.header('=?utf-8?B?5ZGK?='), '告');
    });

    test('沒有 encoded-word 就原樣回去', () {
      expect(MailTextDecoder.header('Re: plain subject'), 'Re: plain subject');
      expect(MailTextDecoder.header(''), '');
    });

    test('解不開的 encoded-word 原樣留著，不吞掉整段主旨', () {
      const raw = '=?big5?B?!!!not-base64!!!?= 尾巴';

      expect(MailTextDecoder.header(raw), contains('尾巴'));
    });

    test('沒補 padding 的 base64 也要解得開', () {
      // 實測有信件的 encoded-word 省略了  padding。
      expect(MailTextDecoder.header('=?big5?B?p2k?='), '告');
    });
  });

  group('上游仍然是壞的（反向哨兵）', () {
    // 這一組故意斷言「上游還沒修好」。哪天 enough_convert / enough_mail 修好
    // 了，它們會變紅——那時就可以把 MailTextDecoder 的補丁整個拿掉。
    test('enough_convert 的 Big5 表仍然少了那 14 個碼位', () {
      const codec = Big5Codec(allowInvalid: true);
      for (final key in MailTextDecoder.big5Patch.keys) {
        expect(codec.decode([key >> 8, key & 0xFF]), '�',
            reason: '0x${key.toRadixString(16)} 上游已經修好了，補丁可以拿掉');
      }
    });

    test('enough_mail 的 decodeSubject 仍然解不出「告」', () {
      final decoded = MimeMessage.parseFromText(
              'Subject: =?big5?B?oWm5cbjqvsewfEVNSbz6wHmkvadpoWoxMTUtMaXTvdCw9qRPrV6k5cDLqXe8+sB5p1mk6bBftn2p8aXTvdA=?=\r\n\r\nbody')
          .decodeSubject();

      expect(decoded, contains('�'));
    });

    test('enough_mail 的 Q-encoding 對 Big5 仍然是全毀的', () {
      final decoded = MimeMessage.parseFromText(
              'Subject: =?big5?Q?=A1i=B9q=B8=EA=BE=C7=B0|EMI=BC=FA=C0y=A4=BD=A7i=A1j115-1=A5=D3=BD=D0=B0=F6=A4O=AD^=A4=E5=C0=CB=A9w=BC=FA=C0y=A7Y=A4=E9=B0=5F=B6}=A9=F1=A5=D3=BD=D0?=\r\n\r\nbody')
          .decodeSubject();

      // 不只那 14 個字，整串中文都散掉。
      expect(decoded, isNot(subject));
      expect(decoded, contains('�'));
    });
  });
}
