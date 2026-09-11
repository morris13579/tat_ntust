import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/auth/session_cleaner.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/auth/app_auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

/// 記錄四個外部副作用有沒有被呼叫。
class _Spy {
  final calls = <String>[];
  bool throwOnWebViewCookies = false;

  SessionCleaner build() => SessionCleaner(
        clearWebViewCookies: () async {
          calls.add('webViewCookies');
          if (throwOnWebViewCookies) {
            throw Exception('platform channel unavailable');
          }
        },
        clearDioCookies: () async => calls.add('dioCookies'),
        clearModel: () async => calls.add('model'),
        clearWidgetImage: () async => calls.add('widgetImage'),
      );
}

/// 只記錄 [deleteAll] 有沒有「跑完」的 cookie jar。
///
/// [deleteAll] 刻意排到下一個 event loop 才標記完成——真實的
/// `PersistCookieJar.deleteAll()` 底下是檔案 I/O，也是這樣。呼叫端如果沒有
/// 把 Future 接回去，斷言當下 [deleteAllCompleted] 就會還是 false，
/// 這正是這個假物件存在的理由。
class _RecordingCookieJar implements CookieJar {
  bool deleteAllCompleted = false;
  bool throwOnDeleteAll = false;

  @override
  bool get ignoreExpires => false;

  @override
  Future<void> deleteAll() async {
    await Future<void>.delayed(Duration.zero);
    if (throwOnDeleteAll) {
      throw Exception('cookie file locked');
    }
    deleteAllCompleted = true;
  }

  @override
  Future<void> delete(Uri uri, [bool withDomainSharedCookie = false]) async {}

  @override
  Future<List<Cookie>> loadForRequest(Uri uri) async => const [];

  @override
  Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => loadTestL10n());
  setUp(resetAppStatics);

  group('SessionCleaner.logoutAll', () {
    test('登入狀態全部歸零', () async {
      // 「全部」要由 `SystemId.values` 給，不能手抄清單：漏掉一顆，
      // 換帳號後 B 就會看到 A 的成績。
      final auth = AppAuthSession()..ssoReady = true;
      AuthSession.instance = auth;
      MoodleWebApiConnector.wsToken = 'a-token';

      await _Spy().build().logoutAll();

      expect(auth.ssoReady, isFalse);
      expect(MoodleWebApiConnector.wsToken, isNull);
    });

    test('Moodle 的 wsToken 與 userId 都歸零', () async {
      MoodleWebApiConnector.wsToken = 'a-token';
      MoodleWebApiConnector.userId = '12345';

      await _Spy().build().logoutAll();

      expect(MoodleWebApiConnector.wsToken, isNull);
      // userId 是從 site_info 快取下來的，留著就是拿 A 的 id 去查 B 的成績。
      expect(MoodleWebApiConnector.userId, isNull);
    });

    test('四個外部副作用都被呼叫', () async {
      final spy = _Spy();
      await spy.build().logoutAll();

      expect(
          spy.calls,
          containsAll(<String>[
            'webViewCookies',
            'dioCookies',
            'model',
            'widgetImage',
          ]));
    });

    test('WebView cookie 是必清項目：漏掉它，成績頁就會沿用前一位使用者的 session', () async {
      // 成績頁走的是 HeadlessInAppWebView，用的是平台 WebView 自己的
      // cookie store，不是 Dio 的 cookie jar，兩邊都要清。
      final spy = _Spy();
      await spy.build().logoutAll();

      expect(spy.calls.contains('webViewCookies'), isTrue);
    });

    test('其中一步拋例外時，後面的步驟仍然會執行', () async {
      final spy = _Spy()..throwOnWebViewCookies = true;
      MoodleWebApiConnector.wsToken = 'a-token';

      await spy.build().logoutAll();

      // 任何一步失敗就中斷整條清理的話，登出會留下殘留。
      expect(spy.calls,
          containsAll(<String>['dioCookies', 'model', 'widgetImage']));
      expect(MoodleWebApiConnector.wsToken, isNull);
    });

    test('logoutAll 本身不會拋出例外', () async {
      final spy = _Spy()..throwOnWebViewCookies = true;
      await expectLater(spy.build().logoutAll(), completes);
    });
  });

  /// 上面那一組注入的都是假 callback，碰不到正式環境真正會跑的
  /// `SessionCleaner.platform()` 的 clearDioCookies；這一組專門測它。
  group('SessionCleaner.platform 的 clearDioCookies', () {
    test('會等到 dio 的 cookie 真的刪完才回來', () async {
      final jar = _RecordingCookieJar();
      DioConnector.instance.cookieJarForTesting = jar;

      await SessionCleaner.platform().clearDioCookies();

      // `deleteAll()` 的 Future 一定要接回去。宣告成 void 把它丟掉的話，
      // 這個 await 會在 cookie 檔還在硬碟上時就回來。
      expect(jar.deleteAllCompleted, isTrue);
    });

    test('刪除失敗會往上拋，logoutAll 的 try/catch 才觀察得到', () async {
      final jar = _RecordingCookieJar()..throwOnDeleteAll = true;
      DioConnector.instance.cookieJarForTesting = jar;

      // Future 一旦跟呼叫端脫鉤，錯誤會變成 unhandled async error，
      // SessionCleaner._step 的 catch 收不到——登出報告「成功」，cookie 還在。
      await expectLater(
          SessionCleaner.platform().clearDioCookies(), throwsException);
    });

    test('接上 logoutAll 之後，dio cookie 刪除失敗不會中斷後面的步驟', () async {
      final jar = _RecordingCookieJar()..throwOnDeleteAll = true;
      DioConnector.instance.cookieJarForTesting = jar;
      final calls = <String>[];
      // clearDioCookies 用正式工廠的那一份，其餘三個注入假的，
      // 避免碰到平台通道。
      final cleaner = SessionCleaner(
        clearWebViewCookies: () async => calls.add('webViewCookies'),
        clearDioCookies: SessionCleaner.platform().clearDioCookies,
        clearModel: () async => calls.add('model'),
        clearWidgetImage: () async => calls.add('widgetImage'),
      );

      await cleaner.logoutAll();

      expect(calls, containsAll(<String>['model', 'widgetImage']));
    });
  });
}
