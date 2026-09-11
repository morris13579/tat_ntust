import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// 「Moodle 回 HTTP 200 但其實是錯誤」這條路徑的規格。
///
/// 測的是 connector 的兩個判斷點（[MoodleWebApiConnector.moodleErrorOf] 與
/// [MoodleWebApiConnector.wsFunctionBlocked]），兩者都是純函式、不需要網路。
/// 要走完整條 `_callWs` 的測試用 [MoodleWebApiConnector.wsPost] 換掉傳輸層
/// （見 moodle_autologin_url_test.dart）。
void main() {
  void resetConnectorStatics() {
    MoodleWebApiConnector.siteInfo = null;
    MoodleWebApiConnector.userId = null;
    MoodleWebApiConnector.onApiError = null;
    // wsToken 放最後：它的 setter 會順手清掉上面兩個快取。
    MoodleWebApiConnector.wsToken = null;
  }

  setUp(resetConnectorStatics);
  tearDown(resetConnectorStatics);

  MoodleProfileEntity profileWith(List<Map<String, dynamic>> functions) =>
      MoodleProfileEntity.fromJson({'functions': functions});

  /// Moodle token 失效時真正回來的東西：HTTP 200，body 是這一包。
  const invalidTokenBody = {
    'exception': 'moodle_exception',
    'errorcode': 'invalidtoken',
    'message': 'Invalid token - token not found',
  };

  group('moodleErrorOf：200 但其實是錯誤', () {
    test('errorcode 的回應會變成帶得出去的例外（舊行為是整包丟掉只回 null）', () {
      final error = MoodleWebApiConnector.moodleErrorOf(
        invalidTokenBody,
        wsFunction: 'gradereport_user_get_grade_items',
      );

      expect(error, isNotNull);
      expect(error!.wsFunction, 'gradereport_user_get_grade_items');
      expect(error.errorcode, 'invalidtoken');
      expect(error.exception, 'moodle_exception');
      expect(error.message, 'Invalid token - token not found');
      expect(error.isInvalidToken, isTrue);
      expect(error.skippedBeforeRequest, isFalse);
      // 呼叫端要看得到內容，所以 toString 必須帶出 errorcode。
      expect(error.toString(), contains('invalidtoken'));
    });

    test('只有 exception 沒有 errorcode 也算失敗', () {
      final error = MoodleWebApiConnector.moodleErrorOf(
        const {'exception': 'webservice_access_exception'},
        wsFunction: 'core_course_get_contents',
      );

      expect(error, isNotNull);
      expect(error!.exception, 'webservice_access_exception');
      expect(error.errorcode, isNull);
      // 只有 invalidtoken 才代表要重新登入，其他錯誤重登入也不會變好。
      expect(error.isInvalidToken, isFalse);
    });

    test('debuginfo 有的話一起帶出來（正式站通常沒有）', () {
      final error = MoodleWebApiConnector.moodleErrorOf(
        const {
          'errorcode': 'invalidparameter',
          'message': 'Invalid parameter value detected',
          'debuginfo': 'Invalid external api parameter: returnusercount',
        },
        wsFunction: 'core_enrol_get_users_courses',
      );

      expect(error!.debugInfo, contains('returnusercount'));
    });

    test('正常回應不會被誤判成錯誤', () {
      expect(
        MoodleWebApiConnector.moodleErrorOf(
          const {'sitename': 'NTUST', 'userid': 123},
          wsFunction: MoodleWebApiConnector.siteInfoFunction,
        ),
        isNull,
      );
      // 課程清單這類回應是 List，不是 Map。
      expect(
        MoodleWebApiConnector.moodleErrorOf(
          const [
            {'id': 1}
          ],
          wsFunction: 'core_enrol_get_users_courses',
        ),
        isNull,
      );
      // captive portal 會回 200 加一段 HTML；那不是 Moodle 的錯誤包，
      // 判給呼叫端自己的轉型去炸（它有 try/catch），這裡不假裝看得懂。
      expect(
        MoodleWebApiConnector.moodleErrorOf(
          '<html>login</html>',
          wsFunction: 'core_course_get_contents',
        ),
        isNull,
      );
    });

    test('讀取路徑的 warnings 不算失敗', () {
      // warnings[] 在讀取路徑上是常態（某個單元沒權限看就會附一筆），
      // 把它當失敗會讓原本能用的頁面整頁消失。刻意與寫入路徑不同。
      final error = MoodleWebApiConnector.moodleErrorOf(
        const {
          'discussions': [],
          'warnings': [
            {'warningcode': '1', 'message': 'some sections were skipped'}
          ],
        },
        wsFunction: 'mod_forum_get_forum_discussions',
      );

      expect(error, isNull);
    });

    test('寫入路徑才把 warnings 當失敗，並帶出 warningcode', () {
      final error = MoodleWebApiConnector.moodleErrorOf(
        const {
          'warnings': [
            {
              'warningcode': 'errorsavingpreference',
              'message': 'Could not save preference',
            }
          ],
        },
        wsFunction: 'core_user_update_user_preferences',
        treatWarningsAsError: true,
      );

      expect(error, isNotNull);
      expect(error!.errorcode, 'errorsavingpreference');
      expect(error.message, 'Could not save preference');
    });

    test('warnings 是空陣列時就算寫入路徑也算成功', () {
      expect(
        MoodleWebApiConnector.moodleErrorOf(
          const {'warnings': []},
          wsFunction: 'core_user_update_user_preferences',
          treatWarningsAsError: true,
        ),
        isNull,
      );
    });

    test('錯誤會帶上站台回報的 function 版本', () {
      // Moodle 會在新版加參數（core_enrol_get_users_courses 的
      // returnusercount 是 3.7 才有），舊站台收到會回 invalidparameter。
      // 一起記下站台實際的版本，log 才分得出「參數打錯」與「站台太舊」。
      MoodleWebApiConnector.siteInfo = profileWith([
        {'name': 'core_enrol_get_users_courses', 'version': '2018051700'},
      ]);

      final error = MoodleWebApiConnector.moodleErrorOf(
        const {'errorcode': 'invalidparameter'},
        wsFunction: 'core_enrol_get_users_courses',
      );

      expect(error!.siteFunctionVersion, '2018051700');
    });
  });

  group('getProfile 的無聲假成功', () {
    test('error map 直接丟給 fromJson 會得到一個看起來合法的空 profile', () {
      // 判錯一定要在 fromJson 之前：MoodleProfileEntity 每個欄位都有
      // defaultValue，錯誤包不會拋，呼叫端會拿到一個「成功」的空 profile，
      // 個人資料卡顯示一個沒有名字的使用者。
      final fake = MoodleProfileEntity.fromJson(invalidTokenBody);

      expect(fake.fullname, '');
      expect(fake.userid, 0);
      expect(fake.functions, isEmpty);
      // 而且這份空 profile 若被存成 siteInfo，會變成「站台什麼都沒開」。
      expect(fake.knowsWsFunctions, isFalse);

      // 所以攔截點必須在 fromJson 之前，也就是 _callWs 用的這個判斷。
      expect(
        MoodleWebApiConnector.moodleErrorOf(
          invalidTokenBody,
          wsFunction: MoodleWebApiConnector.siteInfoFunction,
        ),
        isNotNull,
      );
    });
  });

  group('wsFunctionBlocked：送出前的可用性檢查', () {
    test('siteInfo 還沒載入時一律照打（fail-open）', () {
      // App 剛啟動、或 getProfile 自己失敗時清單就是空的。
      // 把「還不知道」當成「站台沒開放」會讓整個功能無聲消失。
      expect(MoodleWebApiConnector.siteInfo, isNull);
      expect(
        MoodleWebApiConnector.wsFunctionBlocked(
            'gradereport_user_get_grade_items'),
        isNull,
      );
    });

    test('站台沒送 functions 時也照打', () {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity.fromJson({});

      expect(
        MoodleWebApiConnector.wsFunctionBlocked('core_course_get_contents'),
        isNull,
      );
    });

    test('清單裡有的 function 照打', () {
      MoodleWebApiConnector.siteInfo = profileWith([
        {'name': 'core_course_get_contents', 'version': '2022041900'},
      ]);

      expect(
        MoodleWebApiConnector.wsFunctionBlocked('core_course_get_contents'),
        isNull,
      );
    });

    test('清單裡沒有的 function 在送出前就擋下來（舊行為是照打、失敗、吞掉回 null）', () {
      MoodleWebApiConnector.siteInfo = profileWith([
        {'name': 'core_course_get_contents', 'version': '2022041900'},
      ]);

      final blocked = MoodleWebApiConnector.wsFunctionBlocked(
          'gradereport_user_get_grade_items');

      expect(blocked, isNotNull);
      expect(blocked!.wsFunction, 'gradereport_user_get_grade_items');
      // 用 Moodle 自己的 errorcode：送出去的話伺服器也是回這個，
      // 呼叫端不必分辨是誰擋的。
      expect(blocked.errorcode, 'accessexception');
      expect(blocked.skippedBeforeRequest, isTrue);
      expect(blocked.isInvalidToken, isFalse);
    });

    test('site_info 自己永遠不會被擋', () {
      // 擋掉它等於再也拿不到 functions 清單，是死結。
      MoodleWebApiConnector.siteInfo = profileWith([
        {'name': 'core_course_get_contents', 'version': '2022041900'},
      ]);

      expect(
        MoodleWebApiConnector.wsFunctionBlocked(
            MoodleWebApiConnector.siteInfoFunction),
        isNull,
      );
    });
  });

  group('換 token 時的快取', () {
    test('換 wsToken 會清掉 userId 與 site_info（舊行為只有 SessionCleaner 會清）', () {
      // 換 token 就是換身分：不清 userId 的話，改登別的帳號後成績頁還是拿
      // 前一個人的 userid 去查。
      MoodleWebApiConnector.wsToken = 'token-a';
      MoodleWebApiConnector.userId = '12345';
      MoodleWebApiConnector.siteInfo = profileWith([
        {'name': 'core_course_get_contents', 'version': '2022041900'},
      ]);

      MoodleWebApiConnector.wsToken = 'token-b';

      expect(MoodleWebApiConnector.wsToken, 'token-b');
      expect(MoodleWebApiConnector.userId, isNull);
      expect(MoodleWebApiConnector.siteInfo, isNull);
    });

    test('登出（token 設成 null）同樣會清掉', () {
      MoodleWebApiConnector.wsToken = 'token-a';
      MoodleWebApiConnector.userId = '12345';
      MoodleWebApiConnector.siteInfo = profileWith([
        {'name': 'core_course_get_contents', 'version': '2022041900'},
      ]);

      MoodleWebApiConnector.wsToken = null;

      expect(MoodleWebApiConnector.userId, isNull);
      expect(MoodleWebApiConnector.siteInfo, isNull);
    });

    test('重複指派同一個 token 不會把快取清掉', () {
      // restoreToken 之類的路徑可能重複寫入同一個值，那不是換帳號，
      // 清掉只會讓啟動時多打一次 site_info。
      MoodleWebApiConnector.wsToken = 'token-a';
      MoodleWebApiConnector.userId = '12345';

      MoodleWebApiConnector.wsToken = 'token-a';

      expect(MoodleWebApiConnector.userId, '12345');
    });
  });
}
