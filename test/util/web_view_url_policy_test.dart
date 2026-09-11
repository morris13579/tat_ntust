import 'package:flutter_app/src/util/web_view_url_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// [WebViewUrlPolicy] 的白名單規格。原本是 CourseHtmlPage 的兩個 static，
/// 抽出來給作業詳情頁共用；course_html_page_test 那份繼續驗委派還接著。
void main() {
  group('WebViewUrlPolicy.isSafe', () {
    test('http 與 https 放行', () {
      expect(
          WebViewUrlPolicy.isSafe('https://moodle.ntust.edu.tw/x.pdf'), isTrue);
      expect(WebViewUrlPolicy.isSafe('http://example.com'), isTrue);
    });

    test('javascript: 擋掉，大小寫混寫也擋', () {
      expect(WebViewUrlPolicy.isSafe('javascript:alert(1)'), isFalse);
      expect(WebViewUrlPolicy.isSafe('JaVaScRiPt:alert(1)'), isFalse);
    });

    test('前後空白不能用來繞過', () {
      expect(WebViewUrlPolicy.isSafe('   javascript:alert(1)'), isFalse);
      expect(WebViewUrlPolicy.isSafe('  https://a.example  '), isTrue);
    });

    test('data: / file: / 自訂 scheme 一律擋掉', () {
      expect(
          WebViewUrlPolicy.isSafe('data:text/html,<script>alert(1)</script>'),
          isFalse);
      expect(WebViewUrlPolicy.isSafe('file:///etc/passwd'), isFalse);
      expect(WebViewUrlPolicy.isSafe('intent://scan#Intent;scheme=zxing;end'),
          isFalse);
      expect(WebViewUrlPolicy.isSafe('tel:0212345678'), isFalse);
    });

    test('沒有 scheme 的殘缺字串擋掉', () {
      expect(WebViewUrlPolicy.isSafe('page2.html'), isFalse);
      expect(WebViewUrlPolicy.isSafe('#section'), isFalse);
      expect(WebViewUrlPolicy.isSafe(''), isFalse);
    });
  });

  group('WebViewUrlPolicy.handleTap', () {
    test('http(s) 才會開 WebView，交出去的是 trim 過的字串', () {
      final opened = <String>[];
      final handled = WebViewUrlPolicy.handleTap(
        '  https://moodle.ntust.edu.tw/a.html ',
        openInWebView: opened.add,
      );

      expect(opened, ['https://moodle.ntust.edu.tw/a.html']);
      expect(handled, isTrue);
    });

    test('被擋下的連結不開 WebView，而且仍回 true（否則 fwfh 會 launchUrl）', () {
      final opened = <String>[];
      for (final url in [
        'javascript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'file:///etc/passwd',
        'intent://scan#Intent;scheme=zxing;end',
        'page2.html',
      ]) {
        expect(
          WebViewUrlPolicy.handleTap(url, openInWebView: opened.add),
          isTrue,
          reason: '$url 被擋下時必須回報「已處理」',
        );
      }
      expect(opened, isEmpty);
    });
  });
}
