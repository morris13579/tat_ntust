import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_app/src/service/cookie_bridge.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

/// [CookieBridge] 的鏡射規則。
///
/// 測的是「搬過去之後長什麼樣」：網域收窄會靜默弄壞成績頁、secure 旗標掉了
/// 會讓已登入的 SSO cookie 走明文、失敗時先清空會把使用者從「舊 session
/// 還能用」變成「完全登出」。
class _FakeCookieManager implements CookieManager {
  _FakeCookieManager(this.cookies);

  final List<Cookie> cookies;

  // 只有 getCookies 會被呼叫到；其餘交給 noSuchMethod，避免綁死在
  // flutter_inappwebview 的完整介面上（它每次改版都會動）。
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getCookies) {
      return Future<List<Cookie>>.value(cookies);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  final url = WebUri('https://ssoam2.ntust.edu.tw/');

  Cookie cookie(String name, {bool? secure, bool? httpOnly}) => Cookie(
        name: name,
        value: '$name-value',
        isSecure: secure,
        isHttpOnly: httpOnly,
      );

  test('改寫成網域 cookie，不是 host-only', () async {
    final jar = CookieJar();
    final moved = await CookieBridge.mirrorToDio(
      url: url,
      jar: jar,
      manager: _FakeCookieManager([cookie('AuthServer')]),
    );

    expect(moved, 1);
    // 關鍵：stuinfosys 與 i.ntust 是不同 host，只有網域 cookie 跨得過去。
    // 成績頁靠的就是這一點。
    final other =
        await jar.loadForRequest(Uri.parse('https://stuinfosys.ntust.edu.tw/'));
    expect(other.map((c) => c.name), contains('AuthServer'));
  });

  test('secure 旗標保留；取不到時預設 true', () async {
    final jar = CookieJar();
    await CookieBridge.mirrorToDio(
      url: url,
      jar: jar,
      manager: _FakeCookieManager([
        cookie('a', secure: false),
        cookie('b', secure: true),
        cookie('c'), // isSecure 為 null
      ]),
    );

    final saved = {
      for (final c
          in await jar.loadForRequest(Uri.parse('https://i.ntust.edu.tw/')))
        c.name: c
    };
    expect(saved['a']!.secure, isFalse);
    expect(saved['b']!.secure, isTrue);
    // 寧可保守：預設 true，否則配上 usesCleartextTraffic 就等於允許已登入
    // 的 SSO cookie 走明文 http 送出。
    expect(saved['c']!.secure, isTrue, reason: '取不到旗標時要預設 secure');
  });

  test('WebView 沒有 cookie 時回 0，而且不動 jar', () async {
    final jar = CookieJar();
    await jar.saveFromResponse(
        Uri.parse('https://ssoam2.ntust.edu.tw/'), [io.Cookie('old', 'v')]);

    final moved = await CookieBridge.mirrorToDio(
      url: url,
      jar: jar,
      manager: _FakeCookieManager([]),
    );

    expect(moved, 0);
    // 拿到新 cookie 之前不能先 deleteAll：登入失敗時會把使用者從
    // 「舊 session 還能用」直接打成「完全登出」。
    final kept = await jar.loadForRequest(url);
    expect(kept.map((c) => c.name), contains('old'),
        reason: '沒拿到新 cookie 就不該把舊的清掉');
  });

  test('拿到新 cookie 時整批取代，舊的不留', () async {
    final jar = CookieJar();
    await jar.saveFromResponse(url, [io.Cookie('stale', 'v')]);

    await CookieBridge.mirrorToDio(
      url: url,
      jar: jar,
      manager: _FakeCookieManager([cookie('fresh')]),
    );

    final names = (await jar.loadForRequest(url)).map((c) => c.name).toSet();
    expect(names, contains('fresh'));
    expect(names, isNot(contains('stale')),
        reason: '同名 host-only cookie 會蓋過網域版本，整批取代最單純');
  });
}
