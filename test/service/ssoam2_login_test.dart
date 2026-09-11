import 'dart:io';

import 'package:flutter_app/src/service/ssoam2_login.dart';
import 'package:flutter_test/flutter_test.dart';

/// ssoam2 登入腳本只能有一份。
///
/// 這些是結構性的護欄：不驗證登入行為（那需要真的 WebView 與 Turnstile，
/// 離線測不到），而是驗證「只有一個地方知道怎麼填這張表」。少了它，複製出來
/// 的第二份填表實作會靜靜長出來——這在這個專案發生過。
void main() {
  List<File> libDartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// 只看程式碼，不看註解。散文裡提到 `cf-turnstile-response` 是好事——
  /// 那是在解釋為什麼某段程式碼長這樣；被掃到才是誤判。
  String codeOf(File f) => f
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  test('cf-turnstile-response 只能出現在共用腳本裡', () {
    final hits = libDartFiles()
        .where((f) => codeOf(f).contains('cf-turnstile-response'))
        .map((f) => f.path)
        .toList()
      ..sort();

    expect(hits, ['lib/src/service/ssoam2_login.dart'],
        reason: 'Turnstile 的等待條件只該有一份。多出來的檔案代表又複製了一份'
            '登入腳本——那正是先前四份實作的長法。');
  });

  test('ssoam2 的登入頁網址只能出現在共用腳本裡', () {
    final hits = libDartFiles()
        .where((f) => codeOf(f).contains('ssoam2.ntust.edu.tw'))
        .map((f) => f.path)
        .toList()
      ..sort();

    // ntust_connector 持有的是根路徑常數（給 GET 探針用），與登入頁不同。
    expect(
        hits,
        [
          'lib/src/connector/ntust_connector.dart',
          'lib/src/service/ssoam2_login.dart',
        ],
        reason: '登入頁網址散落多處的話，學校換網址時會漏改');
  });

  test('validation-summary-errors 只能出現在共用腳本裡', () {
    // 這份判準被複製過，而複製品比對不到時會掉進成功分支——密碼錯卻回報成功。
    final hits = libDartFiles()
        .where((f) => codeOf(f).contains('validation-summary-errors'))
        .map((f) => f.path)
        .toList()
      ..sort();

    expect(hits, ['lib/src/service/ssoam2_login.dart'], reason: '登入錯誤的判準只該有一份');
  });

  test('登入錯誤判準有兩層：class 與已知句子', () {
    // 第二層是安全網：class 靜靜失效等於無限重送同一組錯密碼。
    final script = File('lib/src/service/ssoam2_login.dart').readAsStringSync();

    expect(script, contains('validation-summary-errors'));
    expect(script, contains('帳號或密碼輸入錯誤'));
    expect(script, contains('username or password is incorrect'));
    expect(script, contains('textContent'),
        reason: 'headless WebView 的 innerText 可能是空的，要留 textContent 後路');
  });

  group('isLoginPage', () {
    test('認得登入頁與它的查詢字串', () {
      expect(
          Ssoam2Login.isLoginPage('https://ssoam2.ntust.edu.tw/account/login'),
          isTrue);
      expect(
          Ssoam2Login.isLoginPage(
              'https://ssoam2.ntust.edu.tw/account/login?ReturnUrl=%2F'),
          isTrue);
    });

    test('不把根路徑當成登入頁', () {
      // ntust_connector 的純 Dio POST 打的就是根路徑，那是它失敗的原因之一。
      expect(Ssoam2Login.isLoginPage('https://ssoam2.ntust.edu.tw/'), isFalse);
    });

    test('null 與其他站台都不是', () {
      expect(Ssoam2Login.isLoginPage(null), isFalse);
      expect(Ssoam2Login.isLoginPage('https://moodle.ntust.edu.tw/'), isFalse);
    });
  });
}
