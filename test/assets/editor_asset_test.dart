import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `assets/editor/` 那三個檔案的規格。
///
/// 這幾條守的東西**只有在真機上才會失敗**：CSP 破了不會有 Dart 例外、
/// `eval` 被擋不會有編譯錯誤，畫面上只是一個安靜壞掉的編輯器。所以這裡直接
/// 讀檔案內容驗形狀，不經過 rootBundle。
void main() {
  String read(String name) => File('assets/editor/$name').readAsStringSync();

  /// 只看真的會跑的部分。註解裡本來就會寫「不可以出現 <script>」這種句子，
  /// 拿註解當違規等於逼人不要寫下理由。
  String withoutHtmlComments(String html) =>
      html.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

  String withoutCssComments(String css) =>
      css.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

  group('editor.html', () {
    late String html;
    late String csp;

    setUpAll(() {
      html = read('editor.html');
      final match = RegExp(
              r'''<meta\s+http-equiv="Content-Security-Policy"\s+content="([^"]*)"''')
          .firstMatch(html);
      expect(match, isNotNull, reason: '整頁的安全性就靠這一行，不可以不見');
      csp = match!.group(1)!;
    });

    test('該有的指示詞一個都不能少', () {
      for (final directive in [
        "default-src 'none'",
        "script-src 'self'",
        "connect-src 'none'",
        "object-src 'none'",
        "base-uri 'none'",
        "form-action 'none'",
      ]) {
        expect(csp, contains(directive));
      }
    });

    test('img-src 只認學校站台', () {
      final imgSrc = csp
          .split(';')
          .map((d) => d.trim())
          .firstWhere((d) => d.startsWith('img-src'));
      expect(imgSrc, 'img-src https://moodle2.ntust.edu.tw');
    });

    test('script-src 沒有 unsafe-inline，整份沒有 unsafe-eval', () {
      final scriptSrc = csp
          .split(';')
          .map((d) => d.trim())
          .firstWhere((d) => d.startsWith('script-src'));
      expect(scriptSrc.contains('unsafe-inline'), isFalse);
      expect(csp.contains('unsafe-eval'), isFalse);
    });

    test('referrer 關掉：圖片網址帶著憑證，不可以流進 Referer', () {
      expect(html, contains('<meta name="referrer" content="no-referrer">'));
    });

    test('沒有內嵌 <script>、沒有 <style>、沒有 on*= ——那是唯一一種靜靜停掉整套政策的寫法', () {
      final code = withoutHtmlComments(html);
      // 每一個 script 標籤都要有 src。
      for (final tag in RegExp(r'<script\b[^>]*>').allMatches(code)) {
        expect(tag.group(0), contains('src='), reason: tag.group(0));
      }
      expect(RegExp(r'<style\b', caseSensitive: false).hasMatch(code), isFalse);
      expect(RegExp(r'\son[a-z]+\s*=', caseSensitive: false).hasMatch(code),
          isFalse);
    });

    test('CSS 與 JS 都是同目錄的獨立檔案（script-src self 才解得開）', () {
      expect(html, contains('href="./editor.css"'));
      expect(html, contains('src="./editor.js"'));
      expect(File('assets/editor/editor.css').existsSync(), isTrue);
      expect(File('assets/editor/editor.js').existsSync(), isTrue);
    });
  });

  group('editor.js', () {
    test('沒有 eval、沒有動態產生函式——CSP 沒有 unsafe-eval，違規只有真機看得到', () {
      final js = withoutCssComments(read('editor.js'));
      expect(js.contains('eval('), isFalse);
      expect(js.contains('new Function'), isFalse);
    });

    test('橋接的三個 handler 名稱與 Dart 那一端對得上', () {
      final js = read('editor.js');
      for (final handler in [
        'tatEditorReady',
        'tatEditorState',
        'tatEditorInput',
      ]) {
        expect(js, contains("'$handler'"));
      }
    });
  });

  group('editor.css', () {
    test('沒有 @import、也沒有指向遠端的 url()——font-src 與 default-src 都是 none', () {
      final css = withoutCssComments(read('editor.css'));
      expect(css.contains('@import'), isFalse);
      expect(RegExp(r'url\(\s*["\x27]?https?:').hasMatch(css), isFalse);
    });
  });

  test('pubspec 有列 assets/editor/——只列 assets/ 不會涵蓋子目錄', () {
    expect(
        File('pubspec.yaml').readAsStringSync(), contains('- assets/editor/'));
  });
}
