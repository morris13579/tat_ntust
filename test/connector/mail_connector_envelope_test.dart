import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/model/mail/mail_message_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// `MimeMessage` → 快取得下去的 envelope。純函式，直接打。
///
/// 網路那半刻意不在單元測試裡：它是 raw socket，測起來只會變成在測
/// `enough_mail`。解碼那一段由 enough_mail_big5_test 守著。
void main() {
  MimeMessage parse(String raw) =>
      MimeMessage.parseFromText(raw.replaceAll('\n', '\r\n'));

  test('主旨、寄件者、日期、已讀旗標都對得上', () {
    final message = parse('''
From: 教務處 <academic@mail.ntust.edu.tw>
Date: Mon, 24 Jul 2023 13:44:50 +0800
Subject: 選課通知

body
''')
      ..uid = 42
      ..flags = [MessageFlags.seen];

    final json = MailConnector.toMessageJson(message);

    expect(json.uid, 42);
    expect(json.subject, '選課通知');
    expect(json.fromName, '教務處');
    expect(json.fromEmail, 'academic@mail.ntust.edu.tw');
    expect(json.seen, isTrue);
    // 比 epoch 而不是比 DateTime：enough_mail 回的是 local flag 的 DateTime，
    // 跟 UTC 的同一瞬間在 Dart 裡 `==` 不成立。我們存的是 epoch，不受影響。
    expect(json.dateMillis,
        DateTime.parse('2023-07-24T13:44:50+0800').millisecondsSinceEpoch);
  });

  test('Big5 主旨走自己的解碼，不受上游那 14 個漏掉的碼位影響', () {
    // 折成兩段、而且切在「告」（A7 69）中間——那是 enough_convert 的表漏掉的
    // 碼位之一，走 decodeSubject() 會變成「公?」。位元組由 Python 的 big5
    // codec 產生。
    final message = parse('''
From: 電資學院 <eecs@mail.ntust.edu.tw>
Date: Wed, 10 Sep 2026 14:36:00 +0800
Subject: =?big5?B?oWm5cbjqvsewfEVNSbz6wHmkvac=?=
	=?big5?B?aaFqMTE1LTGl073QsPakT61epOXAy6l3vPrAeadZpOmwX7Z9qfGl073Q?=

body
''')..uid = 7;

    final json = MailConnector.toMessageJson(message);

    expect(json.subject, '【電資學院EMI獎勵公告】115-1申請培力英文檢定獎勵即日起開放申請');
    expect(json.subject, isNot(contains('\uFFFD')));
  });

  test('信件日期的時區位移有被吃進去', () {
    // 存 epoch 而不是字串，就是為了這件事：同一個牆上時間配不同位移是不同
    // 的瞬間，丟掉位移的話出國的人看到的每封信時間都會偏。
    int millisOf(String zone) {
      final message = parse('''
From: a@example.com
Date: Mon, 24 Jul 2023 13:44:50 $zone
Subject: x

body
''');
      return MailConnector.toMessageJson(message).dateMillis;
    }

    expect(millisOf('+0000') - millisOf('+0800'),
        const Duration(hours: 8).inMilliseconds);
    expect(millisOf('-0500') - millisOf('+0000'),
        const Duration(hours: 5).inMilliseconds);
  });

  test('真實的 Big5 折疊主旨走這條路也解得開', () {
    // 跟 enough_mail_big5_test 用同一份 fixture：那份驗的是套件本身，
    // 這裡驗的是我們的轉換函式沒有把它弄丟。
    final message = MimeMessage.parseFromData(
        File('test/fixtures/mail/big5_subject.eml').readAsBytesSync());
    final expected = File('test/fixtures/mail/big5_subject.expected.txt')
        .readAsStringSync()
        .trim();

    expect(MailConnector.toMessageJson(message).subject, expected);
  });

  test('沒有 Date 標頭的信給 0，不是拋例外', () {
    // 排序時會沉到最底下。信件缺標頭在真實信箱裡不罕見，不能讓整批掛掉。
    final message = parse('''
From: someone@example.com
Subject: 沒有日期

body
''');

    expect(MailConnector.toMessageJson(message).dateMillis, 0);
  });

  test('沒有寄件者時兩個欄位都是空字串，displayFrom 也不塞預設文案', () {
    // 「（無寄件者）」是 l10n 的事，model 不該內建中文。
    final message = parse('''
Subject: 沒有寄件者

body
''');

    final json = MailConnector.toMessageJson(message);
    expect(json.fromName, '');
    expect(json.fromEmail, '');
    expect(json.displayFrom, '');
  });

  group('matchesKeyword', () {
    MailMessageJson m(
            {String subject = '', String name = '', String mail = ''}) =>
        MailMessageJson(
            uid: 1, subject: subject, fromName: name, fromEmail: mail);

    test('主旨、寄件者名稱、寄件者位址三個欄位都比', () {
      expect(MailConnector.matchesKeyword(m(subject: '圖書館活動'), '圖書館'), isTrue);
      expect(MailConnector.matchesKeyword(m(name: '圖書館大宗郵件'), '圖書館'), isTrue);
      expect(MailConnector.matchesKeyword(m(mail: 'library@x.edu'), 'library'),
          isTrue);
    });

    test('大小寫不敏感', () {
      // needle 由呼叫端先轉小寫，這裡驗欄位那一側也有轉。
      expect(
          MailConnector.matchesKeyword(
              m(subject: 'NTUST Bulletin'), 'bulletin'),
          isTrue);
    });

    test('都不符合就回 false', () {
      expect(MailConnector.matchesKeyword(m(subject: '公告'), '研討會'), isFalse);
    });

    test('內文不在比對範圍內', () {
      // envelope 裡沒有內文，要比就得把每封信整封抓下來——那正是要避免的。
      expect(MailConnector.matchesKeyword(m(subject: '公告'), ''), isTrue,
          reason: '空關鍵字視為全部符合，實際上呼叫端會先擋掉');
    });
  });

  group('htmlToPlainText（回覆引言）', () {
    test('style / script / head 要連內容整段拿掉', () {
      // 真機上踩過：只剝標籤的話，Outlook 的 CSS 會整片跑進引言，使用者按下
      // 回覆看到的第一行是 v\:* {behavior:url(#default#VML);}。
      const html = '<html><head><style>v\\:* {behavior:url(#default#VML);}'
          '.shape {behavior:url(#default#VML);}</style></head>'
          '<body><p>各位同學您好</p></body></html>';

      final text = MailConnector.htmlToPlainText(html);

      expect(text, isNot(contains('behavior')));
      expect(text, isNot(contains('VML')));
      expect(text, contains('各位同學您好'));
    });

    test('MSO 的條件註解也拿掉', () {
      const html = '<!--[if gte mso 9]><xml><o:OfficeDocumentSettings>'
          '</o:OfficeDocumentSettings></xml><![endif]--><p>內容</p>';

      expect(MailConnector.htmlToPlainText(html), '內容');
    });

    test('區塊結束會換行，整封信不會黏成一行', () {
      const html = '<p>第一段</p><p>第二段</p><div>第三段</div>';

      expect(MailConnector.htmlToPlainText(html), '第一段\n第二段\n第三段');
    });

    test('連續空行收成一行', () {
      // 不收的話引言會出現一整排只有「> 」的空行。
      const html = '<p>上</p><br><br><br><br><p>下</p>';

      expect(MailConnector.htmlToPlainText(html), '上\n\n下');
    });

    test('&amp; 最後才解，跳脫過的角括號不會變回標籤', () {
      // 先解 &amp; 的話 &amp;lt; 會被還原成 <，等於把寄件者刻意跳脫的東西
      // 又變成標籤。
      expect(MailConnector.htmlToPlainText('<p>a &amp;lt; b</p>'), 'a &lt; b');
      expect(MailConnector.htmlToPlainText('<p>x &lt;y&gt; z</p>'), 'x <y> z');
    });
  });

  group('純文字內文轉 HTML', () {
    test('換行變成 <br>，CRLF 不會多出一個空行', () {
      expect(MailConnector.plainTextToHtml('第一行\r\n第二行\n第三行'),
          '第一行<br>第二行<br>第三行');
    });

    test('角括號被跳脫，不會被 HtmlWidget 當成標籤吃掉', () {
      // 純文字信裡的 <B11000000@mail.ntust.edu.tw> 很常見，不跳脫的話那一段
      // 連同後面的內容都會消失。
      expect(MailConnector.plainTextToHtml('寄給 <someone@example.com> 的信'),
          '寄給 &lt;someone@example.com&gt; 的信');
    });

    test('連續空行收成兩行，一封信才不會被撐得很開', () {
      // 純文字信常常夾著大段空行（簽名檔前後、引言之間）。原樣保留的話要捲
      // 很久才看得到下一段。
      expect(MailConnector.plainTextToHtml('上\n\n\n\n\n下'), '上<br><br>下');
      // 剛好兩行的維持原樣：那是作者刻意的段落分隔。
      expect(MailConnector.plainTextToHtml('上\n\n下'), '上<br><br>下');
      // 單行換行不受影響。
      expect(MailConnector.plainTextToHtml('上\n下'), '上<br>下');
    });

    test('& 先跳脫，不會把後面補進去的實體再吃一次', () {
      // 順序反過來的話 `&lt;` 會變成 `&amp;lt;`，畫面上就看得到字面的 &lt;。
      expect(MailConnector.plainTextToHtml('A & <B>'), 'A &amp; &lt;B&gt;');
    });
  });

  test('只有位址沒有顯示名稱時，displayFrom 退回位址', () {
    final message = parse('''
From: noreply@mail.ntust.edu.tw
Subject: 系統通知

body
''');

    expect(MailConnector.toMessageJson(message).displayFrom,
        'noreply@mail.ntust.edu.tw');
  });
}
