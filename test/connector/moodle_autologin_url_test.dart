import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/store/moodle_session_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';

/// WebView 免登入（autologin）這條路的規格。
///
/// 全部行為都在 connector 裡：[MoodleWebApiConnector.autologinUrl] 拿到什麼
/// 就開什麼，拿不到就原樣開。傳輸層用 [MoodleWebApiConnector.wsPost] 換掉，
/// 所以這裡連 `_callWs` 的 UA 與 POST 欄位都驗得到。
///
/// 沒有 widget 測試：`RouteUtils.toWebViewPage` 與 `InAppWebViewPage` 都會
/// 建出 `InAppWebView` 這個平台 view，在 `flutter test` 裡起不來。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const moodleUrl =
      'https://moodle2.ntust.edu.tw/mod/assign/view.php?id=123&lang=zh_tw';
  const autologinScript =
      'https://moodle2.ntust.edu.tw/admin/tool/mobile/autologin.php';
  const keyOk = {
    'key': '5f3c8a1b2d4e6f7a8b9c0d1e2f3a4b5c',
    'autologinurl': autologinScript,
    'warnings': <dynamic>[],
  };
  const lockoutBody = {
    'exception': 'moodle_exception',
    'errorcode': 'autologinkeygenerationlockout',
    'message': 'Auto-login key generation is blocked. '
        'You need to wait 6 minutes between requests.',
  };
  const appRequiredBody = {
    'exception': 'moodle_exception',
    'errorcode': 'apprequired',
    'message': 'This functionality is only available when accessed via the '
        'Moodle mobile or desktop app.',
  };
  const invalidTokenBody = {
    'exception': 'moodle_exception',
    'errorcode': 'invalidtoken',
    'message': 'Invalid token - token not found',
  };
  const accessBody = {
    'exception': 'webservice_access_exception',
    'errorcode': 'accessexception',
    'message': 'Access control exception',
  };
  const siteInfoBody = {
    'userid': 12345,
    'fullname': 'Test',
    'functions': [
      {'name': 'tool_mobile_get_autologin_key', 'version': '2024100700'},
    ],
  };

  late DateTime now;
  late List<MoodleApiException> errors;

  setUp(() {
    resetAppStatics();
    now = DateTime(2026, 9, 6, 12);
    MoodleWebApiConnector.autologinClock = () => now;
    errors = <MoodleApiException>[];
    MoodleWebApiConnector.onApiError = errors.add;
  });
  tearDown(resetAppStatics);

  /// 順序有意義：wsToken 的 setter 會清掉 userId。
  Future<void> loginAs({String privateToken = 'priv-token'}) async {
    await MoodleSessionStore.instance
        .save(MoodleTokenEntity('sig', 'ws-token', privateToken));
    MoodleWebApiConnector.wsToken = 'ws-token';
    MoodleWebApiConnector.userId = '12345';
  }

  /// 依序回 [responses]；回傳的清單記錄每一次送出的參數。
  List<ConnectorParameter> stubWs(List<dynamic> responses) {
    final captured = <ConnectorParameter>[];
    final queue = List<dynamic>.from(responses);
    MoodleWebApiConnector.wsPost = (parameter) async {
      captured.add(parameter);
      return queue.removeAt(0);
    };
    return captured;
  }

  Map<String, String> queryOf(String url) => Uri.parse(url).queryParameters;

  group('autologinTarget（純函式）', () {
    test('自家 https 網址原樣放行', () {
      expect(MoodleWebApiConnector.autologinTarget(moodleUrl), moodleUrl);
    });

    test('前後空白會被修掉', () {
      expect(
          MoodleWebApiConnector.autologinTarget('  $moodleUrl  '), moodleUrl);
    });

    test('http 不放行：PARAM_LOCALURL 的 wwwroot 前綴比對會失敗', () {
      expect(
        MoodleWebApiConnector.autologinTarget('http://moodle2.ntust.edu.tw/x'),
        isNull,
      );
    });

    test('別的 host 不放行，連舊網域 moodle.ntust.edu.tw 也不行', () {
      expect(MoodleWebApiConnector.autologinTarget('https://example.com/x'),
          isNull);
      expect(
        MoodleWebApiConnector.autologinTarget('https://moodle.ntust.edu.tw/x'),
        isNull,
      );
    });

    test('不是網址的東西一律 null，不拋', () {
      expect(
          MoodleWebApiConnector.autologinTarget('javascript:alert(1)'), isNull);
      expect(MoodleWebApiConnector.autologinTarget(''), isNull);
      expect(MoodleWebApiConnector.autologinTarget('::not a url'), isNull);
    });

    test('帶 userinfo 或 port 的不放行', () {
      expect(
        MoodleWebApiConnector.autologinTarget(
            'https://evil@moodle2.ntust.edu.tw/a'),
        isNull,
      );
      expect(
        MoodleWebApiConnector.autologinTarget(
            'https://moodle2.ntust.edu.tw:8443/a'),
        isNull,
      );
    });

    test('已經是 autologin.php 的網址不再包一層', () {
      expect(
        MoodleWebApiConnector.autologinTarget(
            '$autologinScript?userid=1&key=x'),
        isNull,
      );
    });

    test('非 ASCII 會被 percent-encode（PARAM_URL 只收 ASCII）', () {
      expect(
        MoodleWebApiConnector.autologinTarget(
            'https://moodle2.ntust.edu.tw/x.php?q=中 文'),
        'https://moodle2.ntust.edu.tw/x.php?q=%E4%B8%AD%20%E6%96%87',
      );
    });

    test('uriAddQuery 的 ?& 瑕疵與 fragment 都原樣保留', () {
      const quirk =
          'https://moodle2.ntust.edu.tw/mod/forum/view.php?&lang=zh_tw';
      expect(MoodleWebApiConnector.autologinTarget(quirk), quirk);
      const fragment =
          'https://moodle2.ntust.edu.tw/mod/forum/view.php?id=1#s2';
      expect(MoodleWebApiConnector.autologinTarget(fragment), fragment);
    });
  });

  group('parseAutologinKey', () {
    test('正常回應剝出 key 與 autologinurl', () {
      final parsed = MoodleWebApiConnector.parseAutologinKey(keyOk);

      expect(parsed, isNotNull);
      expect(parsed!.key, '5f3c8a1b2d4e6f7a8b9c0d1e2f3a4b5c');
      expect(parsed.autologinUrl, autologinScript);
    });

    test('key 缺席、為空或不是字串都算形狀不對', () {
      expect(
        MoodleWebApiConnector.parseAutologinKey(
            const {'key': '', 'autologinurl': autologinScript}),
        isNull,
      );
      expect(
        MoodleWebApiConnector.parseAutologinKey(
            const {'autologinurl': autologinScript}),
        isNull,
      );
      expect(MoodleWebApiConnector.parseAutologinKey(const {'key': 'abc'}),
          isNull);
      expect(
        MoodleWebApiConnector.parseAutologinKey(
            const {'key': 123, 'autologinurl': autologinScript}),
        isNull,
      );
    });

    test('錯誤包、HTML、List、null 都回 null', () {
      expect(MoodleWebApiConnector.parseAutologinKey(lockoutBody), isNull);
      expect(MoodleWebApiConnector.parseAutologinKey('<html>'), isNull);
      expect(MoodleWebApiConnector.parseAutologinKey(<dynamic>[]), isNull);
      expect(MoodleWebApiConnector.parseAutologinKey(null), isNull);
    });
  });

  group('buildAutologinUrl', () {
    test('組出 userid / key / urltogo 三個參數，urltogo 完整編碼', () {
      final url = MoodleWebApiConnector.buildAutologinUrl(
        autologinUrl: autologinScript,
        key: 'abc123',
        userId: '12345',
        target: moodleUrl,
      );

      expect(
        url,
        '$autologinScript?userid=12345&key=abc123'
        '&urltogo=https%3A%2F%2Fmoodle2.ntust.edu.tw%2Fmod%2Fassign'
        '%2Fview.php%3Fid%3D123%26lang%3Dzh_tw',
      );
      final query = queryOf(url!);
      expect(query['urltogo'], moodleUrl);
      expect(query['userid'], '12345');
      expect(query['key'], 'abc123');
    });

    test('autologinurl 不是自家 https host 就不組（fail-closed）', () {
      for (final bad in [
        'https://evil.example/autologin.php',
        'http://moodle2.ntust.edu.tw/admin/tool/mobile/autologin.php',
        'not a url',
      ]) {
        expect(
          MoodleWebApiConnector.buildAutologinUrl(
            autologinUrl: bad,
            key: 'abc123',
            userId: '12345',
            target: moodleUrl,
          ),
          isNull,
          reason: bad,
        );
      }
    });

    test('key、userId、target 任一為空都不組', () {
      String? build({
        String key = 'abc123',
        String userId = '12345',
        String target = moodleUrl,
      }) =>
          MoodleWebApiConnector.buildAutologinUrl(
            autologinUrl: autologinScript,
            key: key,
            userId: userId,
            target: target,
          );

      expect(build(key: ''), isNull);
      expect(build(userId: ''), isNull);
      expect(build(target: ''), isNull);
    });

    test('目標含空白時 urltogo 仍能原樣解回來（PHP 把 + 當空白）', () {
      const target = 'https://moodle2.ntust.edu.tw/x.php?q=a b';
      final url = MoodleWebApiConnector.buildAutologinUrl(
        autologinUrl: autologinScript,
        key: 'abc123',
        userId: '12345',
        target: target,
      );

      expect(queryOf(url!)['urltogo'], target);
    });
  });

  group('moodleAppUserAgent 與 preset UA', () {
    test('只在既有 UA 後面附上 MoodleMobile 記號', () {
      final ua = MoodleWebApiConnector.moodleAppUserAgent('Mozilla/5.0 X');

      expect(ua, 'Mozilla/5.0 X MoodleMobile');
      expect(ua, contains('MoodleMobile'));
    });

    test('不會動到 ConnectorParameter.presetUserAgent', () {
      MoodleWebApiConnector.moodleAppUserAgent(
          ConnectorParameter.presetUserAgent);

      expect(ConnectorParameter.presetUserAgent, contains('Safari/604.1'));
      expect(ConnectorParameter.presetUserAgent,
          startsWith('Mozilla/5.0 (iPhone;'));
    });
  });

  group('autologinUrl（走假的 wsPost）', () {
    test('沒有 wsToken：原樣回傳、不打網路', () async {
      final captured = stubWs([keyOk]);

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(captured, isEmpty);
    });

    test('有 token 但 privateToken 為空：原樣回傳、不打網路', () async {
      await loginAs(privateToken: '');
      final captured = stubWs([keyOk]);

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(captured, isEmpty);
    });

    test('store 裡的 token 跟 wsToken 不是同一顆：不打網路', () async {
      // 伺服器查的是 (token, privatetoken) 同一列，拿別顆的 privatetoken
      // 去配一定是 invalidprivatetoken，還會把 autologin 整個關掉。
      await MoodleSessionStore.instance
          .save(MoodleTokenEntity('sig', 'other', 'priv-token'));
      MoodleWebApiConnector.wsToken = 'ws-token';
      MoodleWebApiConnector.userId = '12345';
      final captured = stubWs([keyOk]);

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(captured, isEmpty);
    });

    test('非 Moodle 網址：有 token 也原樣回傳、不打網路', () async {
      await loginAs();
      final captured = stubWs([keyOk]);

      for (final url in [
        'https://forms.gle/x',
        'https://stuinfosys.ntust.edu.tw/NTUSTSSOServ/SSO/ChangePWD',
      ]) {
        expect(await MoodleWebApiConnector.autologinUrl(url), url);
      }
      expect(captured, isEmpty);
    });

    test('成功：回 autologin 網址，請求帶 privatetoken 與 MoodleMobile UA', () async {
      await loginAs();
      final captured = stubWs([keyOk]);

      final result = await MoodleWebApiConnector.autologinUrl(moodleUrl);

      expect(result, startsWith('$autologinScript?'));
      final query = queryOf(result);
      expect(query['userid'], '12345');
      expect(query['key'], '5f3c8a1b2d4e6f7a8b9c0d1e2f3a4b5c');
      expect(query['urltogo'], moodleUrl);

      final request = captured.single;
      expect(request.url,
          '${MoodleWebApiConnector.host}/webservice/rest/server.php');
      expect(request.data,
          containsPair('wsfunction', 'tool_mobile_get_autologin_key'));
      expect(request.data, containsPair('privatetoken', 'priv-token'));
      expect(request.data, containsPair('wstoken', 'ws-token'));
      expect(request.data, containsPair('moodlewsrestformat', 'json'));
      expect(request.userAgent, contains('MoodleMobile'));
      expect(request.userAgent, startsWith(ConnectorParameter.presetUserAgent));
      expect(MoodleWebApiConnector.autologinLastKeyAt, now);
      expect(errors, isEmpty);
    });

    test('MoodleMobile 只影響那一個請求，之後的呼叫用回 preset UA', () async {
      await loginAs();
      stubWs([keyOk]);
      await MoodleWebApiConnector.autologinUrl(moodleUrl);

      final second = stubWs([siteInfoBody]);
      await MoodleWebApiConnector.getProfile();

      expect(second.single.userAgent, ConnectorParameter.presetUserAgent);
      expect(second.single.userAgent, isNot(contains('MoodleMobile')));
      expect(ConnectorParameter.presetUserAgent, contains('Safari/604.1'));
    });

    test('userId 還沒快取：先打 site_info（一般 UA）再取鑰匙', () async {
      await loginAs();
      MoodleWebApiConnector.userId = null;
      final captured = stubWs([siteInfoBody, keyOk]);

      final result = await MoodleWebApiConnector.autologinUrl(moodleUrl);

      expect(captured, hasLength(2));
      expect(captured[0].data,
          containsPair('wsfunction', 'core_webservice_get_site_info'));
      expect(captured[0].userAgent, ConnectorParameter.presetUserAgent);
      expect(captured[1].data,
          containsPair('wsfunction', 'tool_mobile_get_autologin_key'));
      expect(captured[1].userAgent, contains('MoodleMobile'));
      expect(queryOf(result)['userid'], '12345');
      expect(MoodleWebApiConnector.userId, '12345');
    });

    test('伺服器 lockout：原樣開、不算錯誤，6 分鐘內不再打', () async {
      await loginAs();
      final first = stubWs([lockoutBody]);

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(first, hasLength(1));
      expect(errors, isEmpty);
      expect(MoodleWebApiConnector.autologinLastKeyAt, now);
      expect(MoodleWebApiConnector.autologinDisabled, isFalse);

      now = now.add(const Duration(minutes: 5));
      final second = stubWs([keyOk]);
      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(second, isEmpty);

      now = now.add(const Duration(minutes: 1));
      final third = stubWs([keyOk]);
      final result = await MoodleWebApiConnector.autologinUrl(moodleUrl);
      expect(third, hasLength(1));
      expect(queryOf(result)['urltogo'], moodleUrl);
    });

    test('成功之後的本機節流：6 分鐘內不再打，到期才打', () async {
      await loginAs();
      stubWs([keyOk]);
      await MoodleWebApiConnector.autologinUrl(moodleUrl);

      now = now.add(const Duration(minutes: 1));
      final second = stubWs([keyOk]);
      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(second, isEmpty);

      now = now.add(const Duration(minutes: 5));
      final third = stubWs([keyOk]);
      final result = await MoodleWebApiConnector.autologinUrl(moodleUrl);
      expect(third, hasLength(1));
      expect(result, startsWith('$autologinScript?'));
    });

    test('apprequired：關掉 autologin，送 onApiError，之後不再打', () async {
      await loginAs();
      stubWs([appRequiredBody]);

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(MoodleWebApiConnector.autologinDisabled, isTrue);
      expect(errors.single.errorcode, 'apprequired');

      now = now.add(const Duration(minutes: 10));
      final later = stubWs([keyOk]);
      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(later, isEmpty);
    });

    test('伺服器回 accessexception：同樣關掉', () async {
      await loginAs();
      stubWs([accessBody]);

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(MoodleWebApiConnector.autologinDisabled, isTrue);
      expect(errors.single.errorcode, 'accessexception');
    });

    test('site_info 沒列出這個 function：送出前就擋下、關掉', () async {
      await loginAs();
      // 要在 wsToken 之後設：setter 會清掉 siteInfo。
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity.fromJson({
        'functions': [
          {'name': 'core_course_get_contents', 'version': '1'},
        ],
      });
      final captured = stubWs([keyOk]);

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(captured, isEmpty);
      expect(MoodleWebApiConnector.autologinDisabled, isTrue);
      expect(errors.single.skippedBeforeRequest, isTrue);
      expect(errors.single.errorcode, 'accessexception');
    });

    test('invalidtoken：交給 onApiError 作廢 token，不關 autologin、不記時間', () async {
      await loginAs();
      stubWs([invalidTokenBody]);

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(errors.single.isInvalidToken, isTrue);
      expect(MoodleWebApiConnector.autologinDisabled, isFalse);
      expect(MoodleWebApiConnector.autologinLastKeyAt, isNull);
    });

    test('網路例外：原樣開、不拋、不記時間', () async {
      await loginAs();
      MoodleWebApiConnector.wsPost = (_) async =>
          throw DioException(requestOptions: RequestOptions(path: 'x'));

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(MoodleWebApiConnector.autologinLastKeyAt, isNull);
      expect(MoodleWebApiConnector.autologinDisabled, isFalse);
    });

    test('回應不是 JSON（captive portal）：原樣開，但伺服器有答就記時間', () async {
      await loginAs();
      stubWs(['<html>captive portal</html>']);

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
      expect(MoodleWebApiConnector.autologinLastKeyAt, now);
    });

    test('回應缺 key：原樣開', () async {
      await loginAs();
      stubWs([
        const {'autologinurl': autologinScript, 'warnings': <dynamic>[]}
      ]);

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
    });

    test('autologinurl 指到別的 host：原樣開（fail-closed）', () async {
      await loginAs();
      stubWs([
        const {
          'key': 'abc',
          'autologinurl': 'https://evil.example/autologin.php'
        }
      ]);

      final result = await MoodleWebApiConnector.autologinUrl(moodleUrl);

      expect(result, moodleUrl);
      expect(result, isNot(contains('evil.example')));
    });

    test('逾時：在 autologinTimeout 內放棄、原樣開', () async {
      await loginAs();
      MoodleWebApiConnector.autologinTimeout = const Duration(milliseconds: 20);
      MoodleWebApiConnector.wsPost = (_) => Completer<dynamic>().future;

      expect(await MoodleWebApiConnector.autologinUrl(moodleUrl), moodleUrl);
    });

    test('換 token 會清掉節流與 fatal 旗標；同一顆 token 重複指派不會', () {
      MoodleWebApiConnector.wsToken = 'ws-token';
      MoodleWebApiConnector.autologinLastKeyAt = now;
      MoodleWebApiConnector.autologinDisabled = true;

      MoodleWebApiConnector.wsToken = 'ws-token';
      expect(MoodleWebApiConnector.autologinLastKeyAt, now);
      expect(MoodleWebApiConnector.autologinDisabled, isTrue);

      MoodleWebApiConnector.wsToken = 'another';
      expect(MoodleWebApiConnector.autologinLastKeyAt, isNull);
      expect(MoodleWebApiConnector.autologinDisabled, isFalse);
    });

    test('既有 getter 不受 _callWs 改動影響（wsPost 重構的回歸守門）', () async {
      final captured = stubWs([siteInfoBody]);
      MoodleWebApiConnector.wsToken = 'ws-token';

      expect(await MoodleWebApiConnector.isMoodleTokenAvailable(), isTrue);
      expect(MoodleWebApiConnector.userId, '12345');
      expect(captured.single.userAgent, ConnectorParameter.presetUserAgent);
      expect(captured.single.data,
          containsPair('wsfunction', 'core_webservice_get_site_info'));
    });
  });
}
