import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_app/src/auth/interactive_login_flow.dart';
import 'package:flutter_app/src/enum/ntust_login_status.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/service/interactive_login_gateway.dart';
import 'package:flutter_app/src/service/platform_cookies.dart';
import 'package:flutter_app/src/service/ssoam2_headless_login.dart';
import 'package:flutter_app/src/service/web_view_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// 登入流程抽出來之後，Flutter 版的登入頁與原生版的 WKWebView 跑的是同一份。
/// 這裡的規則壞了兩邊一起壞，所以把最容易被「順手修正」弄壞的幾條釘住。
class _FakePage implements WebViewDriver {
  _FakePage({this.error, this.html = ''});

  /// 頁面上的登入錯誤訊息；null 代表乾淨的登入頁。
  String? error;
  String html;
  final scripts = <String>[];
  final loaded = <String>[];

  int get fills =>
      scripts.where((s) => s.contains('.value = ') && s.contains('assword')).length;

  @override
  Future<Object?> evaluateJavascript(String source) async {
    scripts.add(source);
    if (source.contains('JSON.stringify({source: "none"')) {
      return jsonEncode(error == null
          ? {'source': 'none', 'message': ''}
          : {'source': 'class', 'message': error});
    }
    // Ssoam2Login.submit 的等待條件：表單在、挑戰塵埃落定，而且沒有挑戰在跑。
    if (source.contains('readyState')) return true;
    if (source.contains('typeof window.turnstile !== "undefined"')) return false;
    if (source.contains('!= null')) return true;
    return null;
  }

  @override
  Future<String?> getHtml() async => html;

  @override
  Future<void> loadUrl(String url) async => loaded.add(url);
}

class _FakeSource implements PlatformCookieSource {
  _FakeSource(this._cookies);

  final List<PlatformCookie> _cookies;

  @override
  Future<List<PlatformCookie>> cookies(String url) async => _cookies;
}

class _FakeSession extends _FakePage implements WebViewSession {
  _FakeSession({super.error, super.html});

  final controller = StreamController<WebViewEvent>();
  bool closed = false;

  @override
  Stream<WebViewEvent> get events => controller.stream;

  @override
  Future<void> close() async => closed = true;
}

class _FakeHost implements HeadlessWebViewHost {
  _FakeHost(this.session);

  final _FakeSession session;

  @override
  Future<WebViewSession> open(String url) async => session;
}

void main() {
  const loginPage = 'https://ssoam2.ntust.edu.tw/account/login';
  const signedInHtml = 'Issued ... Expires ... You are signed in as B11234567';
  final originalSource = PlatformCookieSource.instance;
  final originalHost = HeadlessWebViewHost.instance;

  tearDown(() {
    PlatformCookieSource.instance = originalSource;
    HeadlessWebViewHost.instance = originalHost;
  });

  PlatformCookie cookie(String name) =>
      PlatformCookie(name: name, value: 'v', secure: true, httpOnly: true);

  group('NtustLoginFlow', () {
    NtustLoginFlow flow() => NtustLoginFlow(
          account: 'B11234567',
          password: 'p"w',
          jar: CookieJar(),
          settle: Duration.zero,
        );

    test('錯誤訊息最先檢查，而且不分網址：不會拿錯帳密再送一次', () async {
      final page = _FakePage(error: '帳號或密碼輸入錯誤\n請重新輸入');
      final step = await flow().onLoadStop(page, NtustLoginFlow.startUrl);

      final finished = step as LoginFinished<NtustInteractiveLoginResult>;
      expect(finished.result.status, NTUSTLoginStatus.fail);
      expect(finished.result.message, '帳號或密碼輸入錯誤請重新輸入');
      expect(page.fills, 0);
    });

    test('在登入頁最多自動送出兩次，之後交給使用者', () async {
      final f = flow();
      final page = _FakePage();

      for (var i = 0; i < 3; i++) {
        expect(await f.onLoadStop(page, NtustLoginFlow.startUrl),
            isA<LoginNeedsHuman<NtustInteractiveLoginResult>>());
      }
      // 每次送出填一次密碼欄；第三次沒有再填。
      expect(page.fills, 2);
      expect(page.scripts.join(), contains(jsonEncode('p"w')));
    });

    test('離開登入頁且搬到 cookie 才算成功', () async {
      PlatformCookieSource.instance = _FakeSource([cookie('AuthServer')]);
      final step = await flow().onLoadStop(_FakePage(), 'https://i.ntust.edu.tw/student');

      expect((step as LoginFinished<NtustInteractiveLoginResult>).result.status,
          NTUSTLoginStatus.success);
    });

    test('離開登入頁卻沒有 cookie 是失敗，不是成功', () async {
      PlatformCookieSource.instance = _FakeSource([]);
      final step = await flow().onLoadStop(_FakePage(), 'https://i.ntust.edu.tw/student');

      expect((step as LoginFinished<NtustInteractiveLoginResult>).result.status,
          NTUSTLoginStatus.fail);
    });

    test('只能結束一次：之後的 onLoadStop 都當成繼續', () async {
      PlatformCookieSource.instance = _FakeSource([cookie('AuthServer')]);
      final f = flow();
      await f.onLoadStop(_FakePage(), 'https://i.ntust.edu.tw/student');

      expect(await f.onLoadStop(_FakePage(), 'https://i.ntust.edu.tw/student'),
          isA<LoginContinue<NtustInteractiveLoginResult>>());
    });
  });

  group('MoodleLoginFlow', () {
    MoodleLoginFlow flow() => MoodleLoginFlow(account: 'B11234567', password: 'pw');

    test('不是 ssoam2 登入頁就繼續等，也不碰頁面', () async {
      final page = _FakePage();
      expect(await flow().onLoadStop(page, 'https://moodle.ntust.edu.tw/'),
          isA<LoginContinue<MoodleTokenEntity?>>());
      expect(page.scripts, isEmpty);
    });

    test('登入頁上有錯誤就結束，並把站台的訊息帶出來', () async {
      final step = await flow().onLoadStop(_FakePage(error: '帳號或密碼輸入錯誤'), loginPage);

      final finished = step as LoginFinished<MoodleTokenEntity?>;
      expect(finished.result, isNull);
      expect(finished.notice, '帳號或密碼輸入錯誤');
    });

    test('送出兩次之後交給使用者', () async {
      final f = flow();
      final page = _FakePage();

      expect(await f.onLoadStop(page, loginPage), isA<LoginContinue<MoodleTokenEntity?>>());
      expect(await f.onLoadStop(page, loginPage), isA<LoginContinue<MoodleTokenEntity?>>());
      expect(await f.onLoadStop(page, loginPage), isA<LoginNeedsHuman<MoodleTokenEntity?>>());
    });

    test('回呼帶著壞掉的 token 也只結束一次', () {
      final f = flow();
      final first = f.onCallback('moodlemobile://token=not-base64');

      expect((first as LoginFinished<MoodleTokenEntity?>).result, isNull);
      expect(f.onCallback('moodlemobile://token=again'),
          isA<LoginContinue<MoodleTokenEntity?>>());
    });
  });

  group('Ssoam2HeadlessLogin 走 HeadlessWebViewHost', () {
    test('平台 store 已經登入：鏡射 cookie 就算成功，並且關掉 WebView', () async {
      PlatformCookieSource.instance = _FakeSource([cookie('AuthServer')]);
      final session = _FakeSession(html: signedInHtml);
      HeadlessWebViewHost.instance = _FakeHost(session);
      session.controller.add(const WebViewLoadStop('https://ssoam2.ntust.edu.tw/'));

      final outcome = await Ssoam2HeadlessLogin.attempt(
          account: 'B11234567', password: 'pw', jar: CookieJar());

      expect(outcome, Ssoam2HeadlessOutcome.success);
      expect(session.closed, isTrue);
    });

    test('登入頁上有錯誤：回報 rejected，不送出表單', () async {
      final session = _FakeSession(error: '帳號或密碼輸入錯誤');
      HeadlessWebViewHost.instance = _FakeHost(session);
      session.controller.add(const WebViewLoadStop(loginPage));

      final outcome = await Ssoam2HeadlessLogin.attempt(
          account: 'B11234567', password: 'pw', jar: CookieJar());

      expect(outcome, Ssoam2HeadlessOutcome.rejected);
      expect(session.fills, 0);
    });

    test('根路徑吐出認不得的表單：導到登入頁一次', () async {
      final session = _FakeSession(error: '帳號或密碼輸入錯誤');
      HeadlessWebViewHost.instance = _FakeHost(session);
      session.controller
        ..add(const WebViewLoadStop('https://ssoam2.ntust.edu.tw/'))
        ..add(const WebViewLoadStop(loginPage));

      final outcome = await Ssoam2HeadlessLogin.attempt(
          account: 'B11234567', password: 'pw', jar: CookieJar());

      expect(session.loaded, [loginPage]);
      expect(outcome, Ssoam2HeadlessOutcome.rejected);
    });

    test('載入失敗：回報 failed', () async {
      final session = _FakeSession();
      HeadlessWebViewHost.instance = _FakeHost(session);
      session.controller.add(const WebViewLoadError('offline'));

      final outcome = await Ssoam2HeadlessLogin.attempt(
          account: 'B11234567', password: 'pw', jar: CookieJar());

      expect(outcome, Ssoam2HeadlessOutcome.failed);
    });
  });
}
