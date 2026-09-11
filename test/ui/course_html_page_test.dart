import 'dart:io';

import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_html_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// `CourseHtmlPage` 的防線接線測試。
///
/// 這頁把 Moodle 的 HTML 教材原文丟給 `HtmlWidget` 算繪，而那份 HTML 是課程上
/// 任何有上傳權限的人寫的，所以兩道防線都不能少：
///
///   1. `onTapUrl` 必須經過 `WebViewUrlPolicy.handleTap` 的白名單只放行
///      http(s)，否則教材裡寫什麼就進 App 內的 WebView（那個 WebView 開著
///      JavaScript，還會灌 App cookie jar 的 cookie）。
///   2. `HtmlWidget` 的 factory 必須關掉 `webView`（預設是 true），
///      否則教材裡的 `<iframe>` 不必使用者點就會變成一個在跑的 WebView。
///
/// 白名單本身的規格在 test/util/web_view_url_policy_test.dart；這裡只驗「頁面
/// 真的接著它」——防線正確但沒接上，那份測試照樣全綠。頁面本體要先發一個
/// 網路請求才畫得出 HtmlWidget，所以掃原始碼而不是 pump 整頁，刻意只比對
/// 寬鬆的片段，免得被 dart format 的換行影響。
void main() {
  group('CourseHtmlPage 的 HtmlWidget factory', () {
    test('關掉 iframe 自動變成內嵌 WebView（舊行為：預設 webView == true）', () {
      // 這是唯一一道「不需使用者互動」的防線：教材裡只要有一個 <iframe>，
      // 預設 factory 就會生出一個開著 JavaScript 的 WebView 在跑第三方頁面。
      expect(courseHtmlWidgetFactory().webView, isFalse);
    });
  });

  group('CourseHtmlPage 的防線接線', () {
    late final String source = File(
      'lib/ui/pages/course_data/screen/sub_page/course_html_page.dart',
    ).readAsStringSync();

    test('onTapUrl 仍然走 WebViewUrlPolicy.handleTap 的白名單', () {
      expect(
        source.contains('WebViewUrlPolicy.handleTap('),
        isTrue,
        reason: 'onTapUrl 必須經過 WebViewUrlPolicy.handleTap，'
            '不能直接把 URL 交給 WebView',
      );
      expect(
        source.contains('onTapUrl:'),
        isTrue,
        reason: '拿掉 onTapUrl 會讓 fwfh 直接用 url_launcher 開任何 scheme',
      );
    });

    test('HtmlWidget 仍然使用關掉 iframe WebView 的 factory', () {
      expect(
        source.contains('factoryBuilder: courseHtmlWidgetFactory'),
        isTrue,
        reason: '少了這行，教材裡的 <iframe> 會自動變成開著 JS 的 WebView',
      );
    });

    test('HtmlWidget 仍然設定 baseUrl', () {
      // baseUrl 是相對連結能被解析成絕對網址的前提；沒有它，
      // 相對連結會以沒有 scheme 的殘缺字串進到 onTapUrl。
      expect(source.contains('baseUrl: _baseUrl'), isTrue);
    });
  });
}
