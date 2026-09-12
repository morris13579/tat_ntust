import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_app/src/connector/mail_connector.dart';
import 'package:flutter_app/src/util/html_style_inliner.dart';
import 'package:flutter_test/flutter_test.dart';

/// `<style>` 區塊展開成行內樣式。
///
/// 存在的理由：`flutter_widget_from_html` 只吃行內的 `style` 屬性。Outlook 和
/// Word 寄出來的信把排版全寫在 `<style>` 裡，不展開等於整封信沒有樣式。
void main() {
  String inline(String html) => HtmlStyleInliner.inline(html);

  test('把規則搬進行內樣式', () {
    final result = inline('<style>p { color: red; }</style><p>內文</p>');

    expect(result, contains('color: red'));
    expect(result, contains('內文'));
  });

  test('展開後 <style> 就拆掉，它已經沒有作用了', () {
    expect(inline('<style>p { color: red; }</style><p>x</p>'),
        isNot(contains('<style>')));
  });

  test('元素原本的行內樣式贏過 <style>', () {
    // CSS 的特異性裡行內樣式最高。這裡靠「後面的宣告蓋前面的」達成同樣結果，
    // 所以原本的 style 必須排在展開進來的後面。
    final result =
        inline('<style>p { color: red; }</style><p style="color: blue">x</p>');

    expect(result.indexOf('color: blue'), greaterThan(result.indexOf('red')));
  });

  test('一條規則多個選擇器，每個都要套到', () {
    final result = inline('<style>p.a, div.a { margin: 0cm; }</style>'
        '<p class="a">一</p><div class="a">二</div>');

    expect('margin: 0cm'.allMatches(result).length, 2);
  });

  test('後面的規則蓋掉前面的同名屬性', () {
    final result =
        inline('<style>p { color: red; } p { color: green; }</style><p>x</p>');

    expect(result, contains('color: green'));
    expect(result, isNot(contains('red')));
  });

  test('@media 整段略過：條件式規則無條件套用會是錯的', () {
    final result =
        inline('<style>@media print { p { display: none; } }</style><p>x</p>');

    expect(result, isNot(contains('display')));
  });

  test('@page 不會讓整份樣式表垮掉', () {
    // Word 一定會產 @page。它底下的 margin box 在 csslib 裡是另一種節點，
    // 讀 property 會丟例外——不能因此吃掉後面的規則。
    final result = inline('<style>@page X { margin: 72.0pt; } '
        'p { color: red; }</style><p>x</p>');

    expect(result, contains('color: red'));
  });

  test('包在 HTML 註解裡的 CSS 一樣要吃到', () {
    // `<style><!-- ... --></style>` 是 Outlook 的固定寫法。
    final result =
        inline('<style><!--\np { color: red; }\n--></style><p>x</p>');

    expect(result, contains('color: red'));
  });

  test('認不得的選擇器只掉那一條，其餘照常', () {
    final result = inline('<style>p:hover { color: blue; } '
        'p { color: red; }</style><p>x</p>');

    expect(result, contains('color: red'));
  });

  test('沒有 <style> 就原封不動回去', () {
    // 大多數信件走這條。連剖析都不做，才不會白白改寫掉好好的 HTML。
    const html = '<p>x</p>';

    expect(inline(html), same(html));
  });

  test('壞掉的 CSS 不會把信弄不見', () {
    final result = inline('<style>p { color: </style><p>內文還在</p>');

    expect(result, contains('內文還在'));
  });

  group('真實信件', () {
    late String html;

    setUpAll(() {
      final message = MimeMessage.parseFromText(
          File('test/fixtures/mail/big5_multipart.eml').readAsStringSync());
      html = MailConnector.decodeBestTextPart(message, 'text/html')!;
    });

    test('Word 的 p.MsoNormal 排版有套到內文段落上', () {
      // 這封是真的從 Outlook 寄來的信，樣式全部在 <style> 裡。展開前內文的
      // <p class=MsoNormal> 完全沒有 style 屬性。
      expect(html, contains('p.MsoNormal, li.MsoNormal, div.MsoNormal'));

      final result = inline(html);

      // 序列化時 `"` 會轉成實體，這是對的 HTML，fwfh 讀得回來。
      expect(result, contains('font-family: &quot;Calibri&quot;,sans-serif'));
      expect(result, contains('font-size: 12.0pt'));
      expect(result, isNot(contains('p.MsoNormal, li.MsoNormal')));
    });

    test('條件式註解裡的 <style> 原樣留著', () {
      // `<!--[if !mso]><style>...</style><![endif]-->` 整段是註解，html 剖析器
      // 不會把它當成元素，所以我們也碰不到它——而它本來就不會算繪。
      expect(inline(html), contains(r'v\:* {behavior:url(#default#VML);}'));
    });

    test('超連結的顏色有跟著進來', () {
      expect(inline(html), contains('color: #0563C1'));
    });

    test('Word 的 mso-* 不往行內塞', () {
      // 展開前 `<style>` 裡就有 mso-style-priority，展開後不該多出這個屬性。
      expect(html, contains('mso-style-priority'));

      expect(inline(html), isNot(contains('mso-style-priority')));
    });

    test('內文與內嵌圖片都還在', () {
      // 這一步之後才輪到 inlineCidImages 把 cid: 換成 data URI，把 src 弄丟
      // 的話圖片就永遠出不來了。
      final result = inline(html);

      expect(result, contains('各位同學您好'));
      expect(result, contains('雙語教育推動辦公室'));
      expect(result, contains('cid:image001.png@01DD4043.D5EB0A40'));
    });
  });
}
