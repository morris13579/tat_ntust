import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/connector/ntust_connector.dart';
import 'package:flutter_app/src/enum/ntust_login_status.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/service/cookie_bridge.dart';
import 'package:flutter_app/src/service/interactive_login_gateway.dart';
import 'package:flutter_app/src/service/ssoam2_login.dart';
import 'package:flutter_app/src/service/web_view_session.dart';

/// 可見登入頁在一次 onLoadStop 之後要做的事。
///
/// 兩個登入頁的流程只有一份：Flutter 版的頁面與原生版的 WKWebView 都照這裡回傳的步驟做，
/// 差別只在 WebView 在哪一側、遮罩與提示由誰畫。
sealed class LoginStep<T> {
  const LoginStep();
}

/// 還沒結束，等下一頁。
final class LoginContinue<T> extends LoginStep<T> {
  const LoginContinue();
}

/// 自動填表放棄了：收起遮罩，提示使用者自己操作（多半是驗證碼）。
final class LoginNeedsHuman<T> extends LoginStep<T> {
  const LoginNeedsHuman();
}

/// 結束：關掉頁面、交回 [result]。[notice] 非 null 時要先提示使用者。
final class LoginFinished<T> extends LoginStep<T> {
  const LoginFinished(this.result, {this.notice});

  final T result;
  final String? notice;
}

/// 可見的 ssoam2 登入頁。
class NtustLoginFlow {
  NtustLoginFlow({
    required this.account,
    required this.password,
    CookieJar? jar,
    this.settle = const Duration(seconds: 5),
  }) : _jar = jar;

  final String account;
  final String password;
  final CookieJar? _jar;

  /// 送出之後等多久才收起遮罩。
  final Duration settle;

  static const String startUrl = NTUSTConnector.ntustLoginUrl;

  /// 認不出錯誤時的第二道保險：無限重送同一組錯密碼會被站台鎖住。
  static const int _maxSubmits = 2;

  int _submits = 0;

  /// 只能結束一次：登入成功後的 client-side 導向會讓 onLoadStop 在同一次登入裡再觸發一遍，
  /// 多結束一次會把底下那一頁也關掉。
  bool _finished = false;

  Future<LoginStep<NtustInteractiveLoginResult>> onLoadStop(
      WebViewDriver web, String? url) async {
    if (_finished) return const LoginContinue();
    // 錯誤檢查在最前面，而且不分網址：登入失敗後站台是把登入頁連同錯誤訊息重新吐回來，
    // 網址仍是登入頁，放在後面就永遠讀不到，而且會拿同一組錯帳密一直重送。
    final error = await Ssoam2Login.credentialError(web);
    if (error != null) {
      return _finish(NtustInteractiveLoginResult(
        status: NTUSTLoginStatus.fail,
        message: error.replaceAll("\n", ""),
      ));
    }

    if (url == startUrl) {
      if (_submits >= _maxSubmits) return const LoginNeedsHuman();
      _submits++;
      await web.evaluateJavascript(
          'document.getElementsByName("UserName")[0].value = ${jsonEncode(account)};');
      await web.evaluateJavascript(
          'document.getElementsByName("Username")[0].value = ${jsonEncode(account)};');
      await web.evaluateJavascript(
          'document.getElementsByName("Password")[0].value = ${jsonEncode(password)};');
      await web.evaluateJavascript(
          'document.getElementById("btnLogIn").click();');
      await web.evaluateJavascript(
          'document.getElementById("loginButton").click();');
      await Future<void>.delayed(settle);
      return _finished ? const LoginContinue() : const LoginNeedsHuman();
    }

    // 不可以先清 Dio jar：清空由 CookieBridge 在寫入前做，而且只有真的拿到 cookie 才清，
    // 否則登入失敗會把還能用的舊 session 一起清掉。錯誤判斷已在最上面做完，這裡只剩
    // 「離開登入頁＝成功」；不要再 parse 一次判準，比對不到就會變成密碼錯卻回報成功。
    final moved = await CookieBridge.mirrorToDio(
      url: NTUSTConnector.ntustLoginUrl,
      jar: _jar ?? DioConnector.instance.cookiesManager,
    );
    return _finish(NtustInteractiveLoginResult(
      status: moved > 0 ? NTUSTLoginStatus.success : NTUSTLoginStatus.fail,
    ));
  }

  LoginStep<NtustInteractiveLoginResult> _finish(
      NtustInteractiveLoginResult result) {
    if (_finished) return const LoginContinue();
    _finished = true;
    return LoginFinished(result);
  }
}

/// 可見的 Moodle 登入頁：走 ssoam2 登入之後，Moodle 以 `moodlemobile://` 把 token 交回來。
class MoodleLoginFlow {
  MoodleLoginFlow({required this.account, required this.password})
      : _launch = MoodleWebApiConnector.buildLoginLaunch();

  final String account;
  final String password;
  final ({String url, String passport}) _launch;

  String get startUrl => _launch.url;

  /// 要在導航時攔下來的 scheme。
  static const String callbackScheme = "moodlemobile";

  static const int _maxSubmits = 2;
  int _submits = 0;
  bool _finished = false;

  /// 導到 [callbackScheme] 時呼叫。
  LoginStep<MoodleTokenEntity?> onCallback(String url) =>
      _finish(parseMoodleToken(url, passport: _launch.passport));

  Future<LoginStep<MoodleTokenEntity?>> onLoadStop(
      WebViewDriver web, String? url) async {
    if (_finished || !Ssoam2Login.isLoginPage(url)) {
      return const LoginContinue();
    }
    // 先問有沒有錯誤再決定要不要送出：密碼錯時站台是把登入頁連同錯誤訊息重新吐回來，
    // 先送出就會變成拿同一組錯帳密無限重送。
    final error = await Ssoam2Login.credentialError(web);
    if (error != null) return _finish(null, notice: error);
    if (_submits >= _maxSubmits) return const LoginNeedsHuman();
    _submits++;
    final outcome = await Ssoam2Login.submit(
      web,
      account: account,
      password: password,
    );
    // 找不到表單與 Turnstile 逾時在畫面上是同一件事：收起遮罩讓使用者自己操作。
    return outcome == Ssoam2LoginOutcome.submitted
        ? const LoginContinue()
        : const LoginNeedsHuman();
  }

  LoginStep<MoodleTokenEntity?> _finish(MoodleTokenEntity? token,
      {String? notice}) {
    if (_finished) return const LoginContinue();
    _finished = true;
    return LoginFinished(token, notice: notice);
  }
}

/// 解析 `moodlemobile://token=<base64>` 的回傳。失敗一律回 null，不拋例外：從導航回呼逸出的
/// 例外沒有人接，頁面與遮罩會永遠卡在畫面上。
///
/// base64 解開是 `signature:::token:::privatetoken`，要用 base64.normalize 補 padding。
///
/// **signature 不相符一律拒收（fail-closed）。** 伺服器算的是 `md5($CFG->wwwroot . $passport)`
/// （見 `admin/tool/mobile/launch.php`），驗它才能確定 token 來自我們剛發出的那一次 launch。
/// 學校若改了 wwwroot，這裡會開始擋掉合法的 token，症狀是登入頁一直重來：先看 log 裡的
/// `signature mismatch` 反推站台實際的 wwwroot，再更新 [MoodleWebApiConnector.host]——
/// 不要把這道檢查關掉。
MoodleTokenEntity? parseMoodleToken(String rawUrl, {String? passport}) {
  try {
    final marker = rawUrl.indexOf("token=");
    if (marker < 0) return null;
    final encoded = rawUrl.substring(marker + "token=".length);
    if (encoded.isEmpty) return null;

    final decoded = utf8.decode(base64.decode(base64.normalize(encoded)));
    final parts = decoded.split(":::");
    if (parts.length < 2 || parts[1].isEmpty) return null;

    if (passport != null &&
        !MoodleWebApiConnector.verifyLoginSignature(parts[0], passport)) {
      Log.e("moodle login signature mismatch: got ${parts[0]}");
      return null;
    }

    return MoodleTokenEntity(
      parts[0],
      parts[1],
      parts.length >= 3 ? parts[2] : "",
    );
  } catch (e, stack) {
    Log.eWithStack("moodle token parse failed: $e", stack);
    return null;
  }
}
