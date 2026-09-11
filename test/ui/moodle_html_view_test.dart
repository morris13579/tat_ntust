import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/html/moodle_html_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

/// Moodle 原文 HTML 算繪元件的規格。輸入是課程上任何有發文權限的人提供的
/// HTML，所以「哪些連結會被當成自家檔案」是安全性質的判斷。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ownFile =
      'https://moodle2.ntust.edu.tw/pluginfile.php/123/mod_forum/post/900/a.pdf';

  Future<List<(String, String)>> pump(
    WidgetTester tester,
    String html, {
    Brightness brightness = Brightness.light,
  }) async {
    final opened = <(String, String)>[];
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: MoodleHtmlView(
          html: html,
          title: '公告',
          dirName: '作業系統',
          openWebView: (title, url) async => opened.add((title, url)),
        ),
      ),
    ));
    return opened;
  }

  bool tapUrl(WidgetTester tester, String url) =>
      tester.widget<HtmlWidget>(find.byType(HtmlWidget)).onTapUrl!(url) as bool;

  TextStyle? styleOf(WidgetTester tester, String text) {
    TextStyle? found;
    tester
        .widget<RichText>(find.textContaining(text, findRichText: true).first)
        .text
        .visitChildren((span) {
      if (span is TextSpan && (span.text ?? '').contains(text)) {
        found = span.style;
        return false;
      }
      return true;
    });
    return found;
  }

  group('連結', () {
    testWidgets('別人站台的 pluginfile.php 不算自家檔案，交給 WebView 而不是直接下載',
        (tester) async {
      final opened = await pump(tester, '<p>x</p>');

      const evil = 'https://evil.example/pluginfile.php/1/x.apk';
      expect(tapUrl(tester, evil), isTrue);

      expect(opened, [('公告', evil)]);
    });

    testWidgets('自家 pluginfile 走下載，不會被丟進 WebView', (tester) async {
      final opened = await pump(tester, '<p>x</p>');

      // 下載本身要平台通道，這裡只驗它沒有走 WebView 那條。
      expect(tapUrl(tester, ownFile), isTrue);
      expect(opened, isEmpty);
    });

    testWidgets('一般連結照樣交給注入的 openWebView', (tester) async {
      final opened = await pump(tester, '<p>x</p>');

      expect(tapUrl(tester, 'https://example.com/a'), isTrue);
      expect(opened, [('公告', 'https://example.com/a')]);
    });

    testWidgets('javascript: 被擋掉，兩條路都不走', (tester) async {
      final opened = await pump(tester, '<p>x</p>');

      expect(tapUrl(tester, 'javascript:alert(1)'), isTrue);
      expect(opened, isEmpty);
    });
  });

  group('downloadNameOf', () {
    test('取最後一段當檔名', () {
      expect(MoodleHtmlView.downloadNameOf(ownFile), 'a.pdf');
    });

    test('解碼後會跳出下載目錄的一段一律不用，改讓伺服器標頭決定', () {
      expect(
        MoodleHtmlView.downloadNameOf(
            'https://moodle2.ntust.edu.tw/pluginfile.php/1/%2E%2E%2Fevil.apk'),
        '',
      );
      expect(
        MoodleHtmlView.downloadNameOf(
            'https://moodle2.ntust.edu.tw/pluginfile.php/1/%2E%2E'),
        '',
      );
      expect(
          MoodleHtmlView.downloadNameOf('https://moodle2.ntust.edu.tw/'), '');
    });
  });

  group('顏色', () {
    const html = '<p><span style="color:#000000">內容</span></p>';

    testWidgets('淺色模式照用 HTML 自己寫的顏色', (tester) async {
      await pump(tester, html);

      expect(styleOf(tester, '內容')?.color, const Color(0xFF000000));
    });

    testWidgets('深色模式中和掉行內顏色，否則老師從 Word 貼上的黑字會壓在深色底上', (tester) async {
      await pump(tester, html, brightness: Brightness.dark);

      final scheme = ThemeData(brightness: Brightness.dark).colorScheme;
      expect(styleOf(tester, '內容')?.color, scheme.onSurface);
    });
  });
}
