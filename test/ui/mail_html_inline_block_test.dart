import 'package:flutter/material.dart';
import 'package:flutter_app/src/util/html_style_inliner.dart';
import 'package:flutter_app/ui/components/html/no_embedded_web_view_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

WidgetFactory _factory() => NoEmbeddedWebViewFactory();
WidgetFactory _darkFactory() =>
    NoEmbeddedWebViewFactory(neutralizeColors: true);

/// 畫面上所有指定底色的方塊，連同它們的大小。
List<(Color, Size)> paintedBoxes(WidgetTester tester) => find
    .byType(DecoratedBox)
    .evaluate()
    .map((e) => (
          (e.widget as DecoratedBox).decoration,
          (e.renderObject as RenderBox).size
        ))
    .where(
        (p) => p.$1 is BoxDecoration && (p.$1 as BoxDecoration).color != null)
    .map((p) => ((p.$1 as BoxDecoration).color!, p.$2))
    .toList();

Future<void> pumpHtml(WidgetTester tester, String html,
    {bool dark = false}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: HtmlWidget(
          HtmlStyleInliner.inline(html),
          key: ValueKey(dark),
          enableCaching: false,
          renderMode: RenderMode.column,
          buildAsync: false,
          textStyle: const TextStyle(fontSize: 14, height: 1.5),
          factoryBuilder: dark ? _darkFactory : _factory,
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

/// 每一段文字畫在哪裡、多大。
Future<List<Rect>> layout(WidgetTester tester, String html) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: HtmlWidget(
          HtmlStyleInliner.inline(html),
          renderMode: RenderMode.column,
          buildAsync: false,
          textStyle: const TextStyle(fontSize: 14, height: 1.5),
          factoryBuilder: _factory,
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));
  final out = <Rect>[];
  for (final e in find.byType(RichText).evaluate()) {
    final text = (e.widget as RichText).text.toPlainText().trim();
    if (text.isEmpty || text == '\u{fffc}') continue;
    final box = e.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    out.add(box.localToGlobal(Offset.zero) & box.size);
  }
  return out;
}

/// Google 日曆邀請與 MJML 電子報的欄位排法：外層消空白，裡面幾個
/// `inline-block` 的 div 當欄位。fwfh 沒有實作 inline-block。
const _mjmlColumns = '''
<div style="font-size: 0;">
  <div style="font-size: 13px; display: inline-block; vertical-align: top; width: 100%;">
    <div>Join with Google Meet</div>
  </div>
  <div style="font-size: 13px; display: inline-block; vertical-align: top; width: 100%;">
    <div>When</div>
  </div>
  <div style="font-size: 13px; display: inline-block; vertical-align: top; width: 100%;">
    <div>Guests</div>
  </div>
</div>
''';

/// 「Join with Google Meet」那顆按鈕的真實結構：底色在最裡面那個 `<td>`，
/// 而那張 `<table>` 帶著 `display: inline-block`。
const _tableButton = '''
<a href="https://meet.google.com/abc-defg-hij">
  <table style="display: inline-block;"><tbody><tr>
    <td style="background-color: #1a73e8; padding: 10px 25px; border-radius: 4px;">
      <span style="color: #ffffff; font-weight: 700;">Join with Google Meet</span>
    </td>
  </tr></tbody></table>
</a>
''';

void main() {
  group('展開之後的 HTML', () {
    test('inline-block 被拿掉，其他 display 值留著', () {
      // `display: none` 是要生效的，只動 inline-block 一個值。
      final out = HtmlStyleInliner.inline(
          '<div style="display: inline-block; color: red;">a</div>'
          '<div style="display: none;">b</div>'
          '<div style="display:inline-block">c</div>');

      expect(out.contains('inline-block'), isFalse);
      expect(out.contains('display: none'), isTrue);
      expect(out.contains('color: red'), isTrue);
    });

    test('沒有 <style> 區塊也要處理', () {
      // 多數信的 inline-block 只寫在行內樣式裡。先前這一層看到沒有 <style>
      // 就整個跳過，那些信永遠修不到。
      final out = HtmlStyleInliner.inline(
          '<div style="display: inline-block;">a</div>');

      expect(out.contains('inline-block'), isFalse);
    });

    test('只有 display 一條的話整個 style 屬性拿掉，不要留一個空的', () {
      final out =
          HtmlStyleInliner.inline('<div style="display:inline-block;">a</div>');

      expect(out.contains('style='), isFalse);
    });
  });

  testWidgets('MJML 的欄位要一欄一欄往下排，不是疊在同一點', (tester) async {
    // 實測那封真的邀請信裡，二十幾段文字全部落在 x=65, y=173——畫面上就是一個
    // 有框線的空方塊。
    final rects = await layout(tester, _mjmlColumns);

    expect(rects, hasLength(3));
    final ys = rects.map((r) => r.top).toList();
    expect(ys.toSet().length, 3, reason: '三段各有各的 y，量到的是 $ys');
    expect(ys.last - ys.first, greaterThan(30));
  });

  testWidgets('深色模式下按鈕的底色要留著——作者自己配好的那一組不要中和', (tester) async {
    // 中和是為了處理「從 Word 貼上的 color:#000」：作者只設字色、把底色交給
    // 郵件軟體，深色模式下變成深底黑字。但這顆按鈕是 <td> 藍底配 <span> 白字，
    // 兩個顏色是配好的一組；把底色丟掉就只剩一行白字，按鈕整個不見了。
    await pumpHtml(tester, _tableButton, dark: true);

    const blue = Color(0xff1a73e8);
    expect(paintedBoxes(tester).where((b) => b.$1 == blue), isNotEmpty,
        reason: '深色模式把按鈕的底色一起丟掉了');
  });

  testWidgets('沒有底色的那些還是要中和——不然深色模式會是深底黑字', (tester) async {
    // 這是中和存在的理由，不能因為上一條而失效。
    await pumpHtml(tester, '<p style="color: #000000;">從 Word 貼過來的一段字</p>',
        dark: true);

    final richText = tester.widget<RichText>(find.byType(RichText));
    expect(richText.text.style?.color, isNot(const Color(0xff000000)));
  });

  testWidgets('表格做的按鈕：底色那一格要撐出按鈕的大小，不是貼著字的一條', (tester) async {
    // `<table style="display:inline-block">` 會蓋掉 fwfh 給 <table> 的預設
    // `display: table`，表格演算法整個不註冊，<td> 的底色、內距與圓角都不
    // 算繪——按鈕就只剩一行字。
    await layout(tester, _tableButton);

    const blue = Color(0xff1a73e8);
    final blueBoxes = find.byType(DecoratedBox).evaluate().where((e) {
      final d = (e.widget as DecoratedBox).decoration;
      return d is BoxDecoration && d.color == blue;
    }).toList();

    expect(blueBoxes, isNotEmpty, reason: '找不到那塊藍色的按鈕底');

    final sizes =
        blueBoxes.map((e) => (e.renderObject as RenderBox).size).toList();
    // 內距上下各 10 加一行字，按鈕至少 30 高；貼著字的那一條底色只有字高。
    expect(sizes.any((s) => s.height > 30), isTrue,
        reason: '藍色那一塊沒有被內距撐開，量到 $sizes');
  });
}
