import 'dart:convert';

import 'package:flutter_app/src/service/browser_auto_login.dart';
import 'package:flutter_app/src/service/web_view_session.dart';
import 'package:flutter_test/flutter_test.dart';

class _Driver implements WebViewDriver {
  final List<String> scripts = [];

  @override
  Future<Object?> evaluateJavascript(String source) async {
    scripts.add(source);
    return true;
  }

  @override
  Future<String?> getHtml() async => null;

  @override
  Future<void> loadUrl(String url) async {}
}

/// App 內瀏覽器的代填。Flutter 與原生版共用這一份：認錯頁會在別的網站上填帳密，逸出錯了帳密會被當成 JavaScript 執行。
void main() {
  const account = 'B1123"0223';
  const password = r"pa\ss';word";

  test('只認學校的兩種登入頁', () {
    expect(BrowserAutoLogin.isLoginPage(
            'https://ssoam.ntust.edu.tw/nidp/app/login?id=x'),
        isTrue);
    expect(BrowserAutoLogin.isLoginPage(
            'https://ssoam2.ntust.edu.tw/account/login?ReturnUrl=%2F'),
        isTrue);
    expect(BrowserAutoLogin.isLoginPage('https://moodle2.ntust.edu.tw/login'),
        isFalse);
    expect(BrowserAutoLogin.isLoginPage(null), isFalse);
  });

  test('舊登入頁：帳密逸出成 JavaScript 字串再按登入', () async {
    final web = _Driver();

    final outcome = await BrowserAutoLogin.run(
        web, 'https://ssoam.ntust.edu.tw/nidp/app/login',
        account: account, password: password);

    expect(outcome, BrowserAutoLoginOutcome.submitted);
    expect(web.scripts, hasLength(3));
    expect(web.scripts[0], contains(jsonEncode(account)));
    expect(web.scripts[1], contains(jsonEncode(password)));
    expect(web.scripts[2], contains('loginButton2'));
  });

  test('不是登入頁：什麼都不做', () async {
    final web = _Driver();

    final outcome = await BrowserAutoLogin.run(
        web, 'https://moodle2.ntust.edu.tw/my/',
        account: account, password: password);

    expect(outcome, BrowserAutoLoginOutcome.notLoginPage);
    expect(web.scripts, isEmpty);
  });

  test('ssoam2：表單與挑戰都好了就送出', () async {
    final web = _Driver();

    final outcome = await BrowserAutoLogin.run(
        web, 'https://ssoam2.ntust.edu.tw/account/login',
        account: account, password: password);

    expect(outcome, BrowserAutoLoginOutcome.submitted);
    expect(web.scripts.last, contains('loginButton'));
  });
}
