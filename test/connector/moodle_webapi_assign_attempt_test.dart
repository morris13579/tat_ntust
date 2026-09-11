import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_assign_fixtures.dart';
import '../helpers/reset_statics.dart';

/// remove / start / copy 三支寫入的本機判讀規格。傳輸層用 `wsPost` 換掉，
/// 不碰網路。
///
/// 三支的參數名字是三種拼法（`assignid`+`userid` / `assignid` /
/// `assignmentid`），回應形狀是兩種（Map / 裸陣列），這裡逐一釘住——打錯一個
/// 字伺服器只會回 invalidparameter，看起來跟「沒有權限」分不開。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<ConnectorParameter> sent;

  setUp(() {
    resetAppStatics();
    MoodleWebApiConnector.wsToken = 'token-123';
    MoodleWebApiConnector.siteInfo = null;
    sent = [];
  });

  tearDown(resetAppStatics);

  void stubWs(dynamic response) {
    MoodleWebApiConnector.wsPost = (parameter) async {
      sent.add(parameter);
      return response;
    };
  }

  /// site_info 的 userid 是靠 `_ensureUserId` 走 core_webservice_get_site_info
  /// 補的。這裡直接把 userId 塞好，避免每個案例都多一趟。
  void stubUserId(String id) => MoodleWebApiConnector.userId = id;

  group('writeObjectShapeErrorOf', () {
    test('Map 才是 remove / start 的合法回應', () {
      expect(
          MoodleWebApiConnector.writeObjectShapeErrorOf(const {'status': true},
              wsFunction: 'x'),
          isNull);
    });

    test('String / null / List 一律是 badresponse', () {
      // captive portal 的 HTML、代理錯誤頁、被 validateStatus 放行的 500 都長
      // 這樣，而 moodleErrorOf（第一行就是 `data is! Map` 放行）與
      // treatWarningsAsError 兩個都攔不住。
      for (final body in <dynamic>[
        '<html>Sign in to the network</html>',
        null,
        '',
        const <dynamic>[],
      ]) {
        final error = MoodleWebApiConnector.writeObjectShapeErrorOf(body,
            wsFunction: 'x');
        expect(error, isNotNull, reason: '$body 應該被判成失敗');
        expect(error!.errorcode, 'badresponse');
      }
    });
  });

  group('removeSubmission', () {
    test('送的是 assignid + userid，而且 userid 是真的 id 不是 0', () async {
      stubUserId('5252');
      stubWs(loadMoodleAssignFixture('remove_submission_ok'));

      final ok = await MoodleWebApiConnector.removeSubmission(assignId: 4102);

      expect(ok, isTrue);
      final data = sent.single.data!;
      expect(
          data['wsfunction'], MoodleWebApiConnector.removeSubmissionFunction);
      // 參數名字是 assignid，不是隔壁兩支的 assignmentid。
      expect(data['assignid'], '4102');
      expect(data.containsKey('assignmentid'), isFalse);
      // 這一支沒有 VALUE_DEFAULT，0 不代表「我自己」：帶 0 會落到
      // mod/assign:editothersubmission，學生沒有那個權限。
      expect(data['userid'], '5252');
      expect(data['userid'], isNot('0'));
    });

    test('status 是 false 但 warnings 是空的：不可以當成成功', () async {
      // assign::remove_submission() 在 !$submission（跟另一台裝置搶）時回
      // false 而且一句錯誤都不留，這個回應真的到得了。
      stubUserId('5252');
      stubWs(
          loadMoodleAssignFixture('remove_submission_status_false_no_warning'));

      await expectLater(
        MoodleWebApiConnector.removeSubmission(assignId: 4102),
        throwsA(isA<MoodleApiException>().having(
            (e) => e.errorcode, 'errorcode', 'couldnotremovesubmission')),
      );
    });

    test('warnings 有東西時 treatWarningsAsError 就先攔下來了', () async {
      stubUserId('5252');
      stubWs(loadMoodleAssignFixture('remove_submission_not_found'));

      await expectLater(
        MoodleWebApiConnector.removeSubmission(assignId: 4102),
        throwsA(isA<MoodleApiException>().having(
            (e) => e.errorcode, 'errorcode', 'submissionnotfoundtoremove')),
      );
    });

    test('回的不是物件（captive portal 的 HTML）是 badresponse', () async {
      stubUserId('5252');
      stubWs('<html>Sign in to the network</html>');

      await expectLater(
        MoodleWebApiConnector.removeSubmission(assignId: 4102),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'badresponse')),
      );
    });

    test('拿不到 userid 就不發請求——這一支不能用 0 代表自己', () async {
      stubWs(const {'status': true, 'warnings': []});
      // site_info 也回不出 userid。
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent.add(parameter);
        return const <String, dynamic>{};
      };

      await expectLater(
        MoodleWebApiConnector.removeSubmission(assignId: 4102),
        throwsA(isA<MoodleApiException>()),
      );
      // 只有補 userid 的那一趟 site_info，沒有真的送出 remove。
      expect(
          sent.any((p) =>
              p.data?['wsfunction'] ==
              MoodleWebApiConnector.removeSubmissionFunction),
          isFalse);
    });
  });

  group('startSubmission', () {
    test('只送 assignid，沒有 userid（伺服器寫死 USER->id）', () async {
      stubWs(loadMoodleAssignFixture('start_submission_ok'));

      final result =
          await MoodleWebApiConnector.startSubmission(assignId: 4102);

      expect(result.outcome, AssignStartOutcome.started);
      expect(result.submissionId, 8810);
      final data = sent.single.data!;
      expect(data['wsfunction'], MoodleWebApiConnector.startSubmissionFunction);
      expect(data['assignid'], '4102');
      expect(data.containsKey('userid'), isFalse);
      expect(data.containsKey('assignmentid'), isFalse);
    });

    test('opensubmissionexists 是「接續」不是失敗', () async {
      stubWs(loadMoodleAssignFixture('start_submission_open_exists'));

      final result =
          await MoodleWebApiConnector.startSubmission(assignId: 4102);

      expect(result.outcome, AssignStartOutcome.alreadyRunning);
      // 有 warning 時伺服器什麼都沒寫。
      expect(result.submissionId, 0);
    });

    test('timelimitnotenabled 是「站台把計時關了」，照常進編輯頁', () async {
      // enabletimelimit 這個站台開關沒有任何 WS 讀得到，這則 warning 是
      // 唯一的線索。
      stubWs(loadMoodleAssignFixture('start_submission_no_timelimit'));

      final result =
          await MoodleWebApiConnector.startSubmission(assignId: 4102);

      expect(result.outcome, AssignStartOutcome.noTimeLimit);
    });

    test('submissionnotopen 是唯一真的失敗', () async {
      stubWs(loadMoodleAssignFixture('start_submission_not_open'));

      final result =
          await MoodleWebApiConnector.startSubmission(assignId: 4102);

      expect(result.outcome, AssignStartOutcome.notOpen);
    });

    test('warnings 可以累加，真的失敗的那一個優先', () async {
      // 同時關閉又沒時限會回兩則。
      stubWs(const {
        'submissionid': 0,
        'warnings': [
          {'warningcode': 'timelimitnotenabled', 'message': 'x'},
          {'warningcode': 'submissionnotopen', 'message': 'y'},
        ],
      });

      final result =
          await MoodleWebApiConnector.startSubmission(assignId: 4102);
      expect(result.outcome, AssignStartOutcome.notOpen);
    });

    test('認不得的 warningcode 要拋，不可以默默當成成功', () async {
      stubWs(const {
        'submissionid': 0,
        'warnings': [
          {'warningcode': 'somethingnew', 'message': 'x'},
        ],
      });

      await expectLater(
        MoodleWebApiConnector.startSubmission(assignId: 4102),
        throwsA(isA<MoodleApiException>()),
      );
    });

    test('回的不是物件是 badresponse', () async {
      stubWs('<html>proxy error</html>');

      await expectLater(
        MoodleWebApiConnector.startSubmission(assignId: 4102),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'badresponse')),
      );
    });
  });

  group('copyPreviousAttempt', () {
    test('參數是第三種拼法 assignmentid', () async {
      stubWs(loadMoodleAssignListFixture('copy_previous_ok'));

      final ok =
          await MoodleWebApiConnector.copyPreviousAttempt(assignId: 4102);

      expect(ok, isTrue);
      final data = sent.single.data!;
      expect(data['wsfunction'],
          MoodleWebApiConnector.copyPreviousAttemptFunction);
      expect(data['assignmentid'], '4102');
      expect(data.containsKey('assignid'), isFalse);
    });

    test('回的是裸陣列：一筆 warning 就是失敗', () async {
      stubWs(loadMoodleAssignListFixture('copy_previous_warning'));

      await expectLater(
        MoodleWebApiConnector.copyPreviousAttempt(assignId: 4102),
        throwsA(isA<MoodleApiException>().having(
            (e) => e.errorcode, 'errorcode', 'couldnotcopyprevioussubmission')),
      );
    });

    test('Map 形狀的回應是 badresponse——這一支回的必須是陣列', () async {
      // 隔壁兩支回的就是 Map，形狀貼錯不可以被當成「沒有 warning」。
      stubWs(const {'submissionid': 0, 'warnings': []});

      await expectLater(
        MoodleWebApiConnector.copyPreviousAttempt(assignId: 4102),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'badresponse')),
      );
    });

    test('例外信封仍然由 moodleErrorOf 先攔下來，不會被當成成功', () async {
      // 這個 code 不在伺服器 generate_warning 的訊息表裡，PHP 8 會補一則
      // undefined-key warning；開了 developer debugging 的站台可能因此回
      // 例外信封而不是陣列。
      stubWs(const {
        'exception': 'coding_exception',
        'errorcode': 'codingerror',
        'message': 'Undefined array key',
      });

      await expectLater(
        MoodleWebApiConnector.copyPreviousAttempt(assignId: 4102),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'codingerror')),
      );
    });
  });

  group('站台沒開放這幾支 function 時', () {
    /// 一份寫實的 MOODLE_OFFICIAL_MOBILE_SERVICE：remove 與 start 在裡面，
    /// copy 不在——`mod/assign/db/services.php` 裡它是唯一沒有 `services`
    /// 鍵的 mod_assign_* function。
    void stubMobileService() {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(functions: [
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.removeSubmissionFunction,
            version: '4.5'),
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.startSubmissionFunction,
            version: '4.5'),
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.saveSubmissionFunction, version: '4.5'),
      ]);
    }

    test('真實的行動服務清單：copy 是 false，remove / start 是 true', () {
      stubMobileService();
      expect(MoodleWebApiConnector.canCopyPreviousAttempt, isFalse);
      expect(MoodleWebApiConnector.canRemoveSubmission, isTrue);
      expect(MoodleWebApiConnector.canStartSubmission, isTrue);
    });

    test('copy 被擋下時一趟都不發', () async {
      stubMobileService();
      var calls = 0;
      MoodleWebApiConnector.wsPost = (_) async {
        calls++;
        return const <dynamic>[];
      };

      await expectLater(
        MoodleWebApiConnector.copyPreviousAttempt(assignId: 4102),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.skippedBeforeRequest, 'skipped', isTrue)),
      );
      expect(calls, 0);
    });

    test('remove 被擋下時一趟都不發', () async {
      MoodleWebApiConnector.userId = '5252';
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(functions: [
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.saveSubmissionFunction, version: '4.5'),
      ]);
      var calls = 0;
      MoodleWebApiConnector.wsPost = (_) async {
        calls++;
        return const <String, dynamic>{};
      };

      expect(MoodleWebApiConnector.canRemoveSubmission, isFalse);
      await expectLater(
        MoodleWebApiConnector.removeSubmission(assignId: 4102),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.skippedBeforeRequest, 'skipped', isTrue)),
      );
      expect(calls, 0);
    });

    test('start 被擋下時一趟都不發', () async {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(functions: [
        MoodleProfileFunctions(
            name: MoodleWebApiConnector.saveSubmissionFunction, version: '4.5'),
      ]);
      var calls = 0;
      MoodleWebApiConnector.wsPost = (_) async {
        calls++;
        return const <String, dynamic>{};
      };

      expect(MoodleWebApiConnector.canStartSubmission, isFalse);
      await expectLater(
        MoodleWebApiConnector.startSubmission(assignId: 4102),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.skippedBeforeRequest, 'skipped', isTrue)),
      );
      expect(calls, 0);
    });

    test('site_info 還沒載入時三支都 fail-open', () {
      MoodleWebApiConnector.siteInfo = null;
      expect(MoodleWebApiConnector.canRemoveSubmission, isTrue);
      expect(MoodleWebApiConnector.canStartSubmission, isTrue);
      expect(MoodleWebApiConnector.canCopyPreviousAttempt, isTrue);
    });
  });
}
