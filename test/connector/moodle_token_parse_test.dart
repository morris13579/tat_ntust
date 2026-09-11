import 'dart:convert';

import 'package:flutter_app/ui/auth/moodle_login_page.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

String url(String payload, {bool padded = true}) {
  var encoded = base64.encode(utf8.encode(payload));
  if (!padded) encoded = encoded.replaceAll('=', '');
  return 'moodlemobile://token=$encoded';
}

void main() {
  group('正常情況', () {
    test('三段：signature、token、privatetoken', () {
      final t = parseMoodleToken(url('sig:::tok:::priv'));

      expect(t, isNotNull);
      expect(t!.signature, 'sig');
      expect(t.token, 'tok');
      expect(t.privateToken, 'priv');
    });

    test('只有兩段時 privatetoken 為空字串', () {
      final t = parseMoodleToken(url('sig:::tok'));

      expect(t!.token, 'tok');
      expect(t.privateToken, '');
    });

    test('token 含 base64 標準字母表的 + 與 /', () {
      final t = parseMoodleToken(url('si+g/1:::to+k/2:::pr+v/3'));

      expect(t!.token, 'to+k/2');
    });

    test('沒有 padding 也解得開', () {
      // PHP 的 base64_encode 一定補 padding，但不必依賴這個假設。
      final t = parseMoodleToken(url('sig:::tok:::priv', padded: false));

      expect(t!.token, 'tok');
    });
  });

  group('壞資料一律回 null，不拋例外', () {
    test('網址裡沒有 token=', () {
      // 壞網址一定要回 null：例外從 shouldOverrideUrlLoading 逸出後沒有人
      // 接住，登入頁會永遠關不掉。
      expect(parseMoodleToken('moodlemobile://error=1'), isNull);
    });

    test('token= 後面是空的', () {
      expect(parseMoodleToken('moodlemobile://token='), isNull);
    });

    test('不是合法的 base64', () {
      expect(parseMoodleToken('moodlemobile://token=@@@not-base64@@@'), isNull);
    });

    test('解得開但只有一段', () {
      expect(parseMoodleToken(url('only-one-segment')), isNull);
    });

    test('token 那一段是空字串', () {
      expect(parseMoodleToken(url('sig::::::priv')), isNull);
    });

    test('解出來不是合法 UTF-8', () {
      final bad = base64.encode([0xff, 0xfe, 0xfd]);
      expect(parseMoodleToken('moodlemobile://token=$bad'), isNull);
    });
  });

  group('signature 驗證', () {
    const host = 'https://moodle2.ntust.edu.tw';

    String sign(String base, String passport) =>
        md5.convert(utf8.encode('$base$passport')).toString();

    test('md5(wwwroot + passport) 相符時通過', () {
      expect(
          MoodleWebApiConnector.verifyLoginSignature(
              sign(host, '12345'), '12345'),
          isTrue);
    });

    test('scheme 是 http 的 wwwroot 也接受', () {
      // 官方 App 在比對失敗時會把 https 與 http 對調再算一次，
      // 因為站台設定的 wwwroot 未必與寫死的 host 同一個 scheme。
      final httpHost = host.replaceFirst('https://', 'http://');
      expect(
          MoodleWebApiConnector.verifyLoginSignature(
              sign(httpHost, '12345'), '12345'),
          isTrue);
    });

    test('passport 不同就不相符', () {
      expect(
          MoodleWebApiConnector.verifyLoginSignature(
              sign(host, '11111'), '22222'),
          isFalse);
    });

    test('亂寫的 signature 不相符', () {
      expect(MoodleWebApiConnector.verifyLoginSignature('deadbeef', '12345'),
          isFalse);
    });

    test('signature 不相符時拒收 token', () {
      // signature 不符一律拒收。$CFG->wwwroot 是站台端的設定值，公式一旦與
      // 站台不合就是全體登不進 Moodle，要改這條先實機確認 log 沒有 mismatch。
      expect(parseMoodleToken(url('wrong-sig:::tok:::priv'), passport: '12345'),
          isNull);
    });

    test('沒有傳 passport 時不做 signature 檢查', () {
      // 只有登入頁知道自己擲出的 passport。其他呼叫端（測試、未來可能的
      // 還原路徑）不傳，就退回只做結構檢查，不會因為無從比對而全部拒收。
      final t = parseMoodleToken(url('whatever:::tok:::priv'));

      expect(t, isNotNull);
      expect(t!.token, 'tok');
    });

    test('signature 相符時照常回傳', () {
      final good = sign(host, '999');
      final t = parseMoodleToken(url('$good:::tok:::priv'), passport: '999');

      expect(t!.token, 'tok');
    });
  });
}
