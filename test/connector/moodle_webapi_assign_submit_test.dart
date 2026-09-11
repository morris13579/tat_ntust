import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_assign_fixtures.dart';
import '../helpers/reset_statics.dart';

/// 交作業那兩趟寫入請求的本機判讀規格。傳輸層用 `wsPost` / `uploadPost` 換掉，
/// 不碰網路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<ConnectorParameter> sent;
  late Directory tempDir;

  setUp(() {
    resetAppStatics();
    MoodleWebApiConnector.wsToken = 'token-123';
    sent = [];
    tempDir = Directory.systemTemp.createTempSync('assign_submit_test');
  });

  tearDown(() {
    resetAppStatics();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void stubWs(dynamic response) {
    MoodleWebApiConnector.wsPost = (parameter) async {
      sent.add(parameter);
      return response;
    };
  }

  File makeFile([String name = 'hw.pdf']) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(List<int>.filled(32, 7));
    return file;
  }

  group('writeWarningOf', () {
    test('空陣列是成功', () {
      expect(
          MoodleWebApiConnector.writeWarningOf(const [],
              wsFunction: MoodleWebApiConnector.saveSubmissionFunction),
          isNull);
    });

    test('裸陣列的第一筆 warning 就是失敗——treatWarningsAsError 看不到它', () {
      final body = loadMoodleAssignListFixture('save_submission_warning');

      // 先確認前提：共用的判讀點第一行就是 `if (data is! Map) return null`。
      expect(
        MoodleWebApiConnector.moodleErrorOf(body,
            wsFunction: MoodleWebApiConnector.saveSubmissionFunction,
            treatWarningsAsError: true),
        isNull,
      );

      final warning = MoodleWebApiConnector.writeWarningOf(body,
          wsFunction: MoodleWebApiConnector.saveSubmissionFunction);
      expect(warning, isNotNull);
      expect(warning!.errorcode, 'couldnotsavesubmission');
      expect(warning.message, 'Could not save submission.');
    });

    test('不是 List（正常的 Map 回應）就不判', () {
      expect(
          MoodleWebApiConnector.writeWarningOf(const {'a': 1}, wsFunction: 'x'),
          isNull);
    });
  });

  group('writeShapeErrorOf', () {
    test('List 才是這兩支的合法回應', () {
      expect(MoodleWebApiConnector.writeShapeErrorOf(const [], wsFunction: 'x'),
          isNull);
      expect(
          MoodleWebApiConnector.writeShapeErrorOf(const [
            {'warningcode': 'a'}
          ], wsFunction: 'x'),
          isNull);
    });

    test('String / null / Map 一律是 badresponse', () {
      // captive portal 的 HTML、代理的錯誤頁、被 validateStatus 放行的 500
      // 都長這樣，而 moodleErrorOf 與 writeWarningOf 兩個都會放行。
      for (final body in <dynamic>[
        '<html>Sign in to the network</html>',
        null,
        '',
        const {'ok': true},
      ]) {
        final error =
            MoodleWebApiConnector.writeShapeErrorOf(body, wsFunction: 'x');
        expect(error, isNotNull, reason: '$body 應該被判成失敗');
        expect(error!.errorcode, 'badresponse');
      }
    });
  });

  /// 存回去之前要先拿到資料庫原文。三個設定缺一不可，而 `fileurl` 要單獨
  /// 確認：`util::format_text` 先改寫網址才檢查 `raw`。
  group('getOnlineTextForEdit', () {
    test('三個設定都送，而且是同一支 get_submission_status', () async {
      MoodleWebApiConnector.userId = '5252';
      stubWs(loadMoodleAssignFixture('status_onlinetext_inline'));

      final edit = await MoodleWebApiConnector.getOnlineTextForEdit(4201,
          teamSubmission: false);

      final data = sent.single.data!;
      expect(
          data['wsfunction'], MoodleWebApiConnector.submissionStatusFunction);
      expect(data['assignid'], '4201');
      expect(data['moodlewssettingraw'], 'true');
      expect(data['moodlewssettingfilter'], 'false');
      // 單獨一條：只送 raw 的話 @@PLUGINFILE@@ 照樣會被換成絕對網址。
      expect(data['moodlewssettingfileurl'], 'false');
      expect(edit!.inlineFiles.single.filename, 'Lecture (1).png');
    });

    test('沒有繳交紀錄時回 null，不是一份空的原文', () {
      expect(
          MoodleWebApiConnector.onlineTextForEditOf(
              loadMoodleAssignFixture('status_none'),
              teamSubmission: false),
          isNull);
      expect(
          MoodleWebApiConnector.onlineTextForEditOf('<html>',
              teamSubmission: false),
          isNull);
    });

    test('團隊作業讀的是 teamsubmission 那一筆', () {
      final team = MoodleWebApiConnector.onlineTextForEditOf(
          loadMoodleAssignFixture('status_team_draft'),
          teamSubmission: true);
      final own = MoodleWebApiConnector.onlineTextForEditOf(
          loadMoodleAssignFixture('status_team_draft'),
          teamSubmission: false);

      expect(team, isNotNull);
      expect(team!.rawText, isNot(own?.rawText));
    });
  });

  group('saveSubmission', () {
    test('線上文字加檔案：四個扁平鍵逐一比對', () async {
      stubWs(loadMoodleAssignListFixture('save_submission_ok'));

      final ok = await MoodleWebApiConnector.saveSubmission(
          assignId: 4201, onlineText: '<p>hi</p>', draftItemId: 999);

      expect(ok, isTrue);
      final data = sent.single.data!;
      expect(data['wsfunction'], MoodleWebApiConnector.saveSubmissionFunction);
      expect(data['assignmentid'], '4201');
      expect(data['plugindata[onlinetext_editor][text]'], '<p>hi</p>');
      expect(data['plugindata[onlinetext_editor][format]'], '1');
      // itemid 送 0 才會跳過 draft 同步（官方 App 相同）。
      expect(data['plugindata[onlinetext_editor][itemid]'], '0');
      expect(data['plugindata[files_filemanager]'], '999');
    });

    test('onlineText 是 null 時完全沒有 onlinetext_editor 的鍵', () async {
      stubWs(const []);
      await MoodleWebApiConnector.saveSubmission(
          assignId: 4201, draftItemId: 7);

      final data = sent.single.data! as Map<String, dynamic>;
      expect(data.keys.where((k) => k.startsWith('plugindata')),
          ['plugindata[files_filemanager]']);
    });

    test('draftItemId 是 null 時沒有 files_filemanager——不送就是保留現有檔案', () async {
      stubWs(const []);
      await MoodleWebApiConnector.saveSubmission(
          assignId: 4201, onlineText: 'x');

      expect(sent.single.data!.containsKey('plugindata[files_filemanager]'),
          isFalse);
    });

    test('回的不是陣列（captive portal 的 HTML）不可以被當成成功', () async {
      stubWs('<html>Sign in to the network</html>');

      await expectLater(
        MoodleWebApiConnector.saveSubmission(
            assignId: 4201, onlineText: '<p>x</p>'),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'badresponse')),
      );
    });

    test('兩者都是 null 會拋 ArgumentError，而且一趟都不發', () async {
      stubWs(const []);
      expect(() => MoodleWebApiConnector.saveSubmission(assignId: 4201),
          throwsA(isA<ArgumentError>()));
      expect(sent, isEmpty);
    });

    test('回一筆 warning 就是失敗，不可以當成成功', () async {
      stubWs(loadMoodleAssignListFixture('save_submission_warning'));

      await expectLater(
        MoodleWebApiConnector.saveSubmission(assignId: 4201, onlineText: 'x'),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'couldnotsavesubmission')),
      );
    });

    test('Map 形狀的例外照樣被 moodleErrorOf 抓到（submissionslocked）', () async {
      stubWs({
        'exception': 'moodle_exception',
        'errorcode': 'submissionslocked',
        'message': 'Submissions are locked',
      });

      await expectLater(
        MoodleWebApiConnector.saveSubmission(assignId: 4201, onlineText: 'x'),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'submissionslocked')),
      );
    });

    test('寫入失敗會通知 onApiError（token 死掉要清），而且例外不被吞掉', () async {
      final seen = <MoodleApiException>[];
      MoodleWebApiConnector.onApiError = seen.add;
      stubWs({'exception': 'x', 'errorcode': 'invalidtoken'});

      await expectLater(
        MoodleWebApiConnector.saveSubmission(assignId: 1, onlineText: 'x'),
        throwsA(isA<MoodleApiException>()),
      );
      expect(seen.single.isInvalidToken, isTrue);
    });
  });

  group('submitForGrading', () {
    test('acceptsubmissionstatement 是 "1" / "0"', () async {
      stubWs(const []);
      await MoodleWebApiConnector.submitForGrading(
          assignId: 4201, acceptStatement: true);
      expect(sent.single.data!['acceptsubmissionstatement'], '1');
      expect(sent.single.data!['wsfunction'],
          MoodleWebApiConnector.submitForGradingFunction);

      sent.clear();
      await MoodleWebApiConnector.submitForGrading(
          assignId: 4201, acceptStatement: false);
      expect(sent.single.data!['acceptsubmissionstatement'], '0');
    });

    test('couldnotsubmitforgrading 會拋', () async {
      stubWs([
        {
          'item': 'User id: 1, Assignment id: 2 Notices:',
          'itemid': 2,
          'warningcode': 'couldnotsubmitforgrading',
          'message': 'Could not submit for grading.',
        }
      ]);

      await expectLater(
        MoodleWebApiConnector.submitForGrading(
            assignId: 4201, acceptStatement: true),
        throwsA(isA<MoodleApiException>().having(
            (e) => e.errorcode, 'errorcode', 'couldnotsubmitforgrading')),
      );
    });

    test('回的不是陣列不可以被當成成功', () async {
      stubWs(null);

      await expectLater(
        MoodleWebApiConnector.submitForGrading(
            assignId: 4201, acceptStatement: true),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'badresponse')),
      );
    });
  });

  group('uploadDraftFile 的 itemid', () {
    late List<FormData> bodies;

    void stubUpload() {
      bodies = [];
      MoodleWebApiConnector.uploadPost = (
        parameter, {
        required FormData formData,
        Duration? sendTimeout,
        ProgressCallback? onSendProgress,
        CancelToken? cancelToken,
      }) async {
        bodies.add(formData);
        return '[{"filename":"hw.pdf","filepath":"/","itemid":555,'
            '"filesize":32}]';
      };
    }

    test('送了 draftItemId 就會出現在 FormData', () async {
      stubUpload();
      await MoodleWebApiConnector.uploadDraftFile(makeFile(),
          filename: 'hw.pdf', draftItemId: 12345);

      final fields = {
        for (final f in bodies.single.fields) f.key: f.value,
      };
      expect(fields['itemid'], '12345');
    });

    test('null 或 0 時沒有 itemid，讓伺服器開新的 draft 區', () async {
      for (final id in [null, 0]) {
        stubUpload();
        await MoodleWebApiConnector.uploadDraftFile(makeFile(),
            filename: 'hw.pdf', draftItemId: id);
        expect(bodies.single.fields.map((e) => e.key), ['token'],
            reason: 'draftItemId=$id');
      }
    });
  });

  group('downloadFileTo', () {
    test('非自家 host 直接回 false，不附憑證也不下載', () async {
      var called = false;
      MoodleWebApiConnector.fileDownloader =
          (url, savePath, {cancelToken, onProgress}) async => called = true;

      expect(
          await MoodleWebApiConnector.downloadFileTo(
              'https://evil.example.com/x.pdf', '${tempDir.path}/x.pdf'),
          isFalse);
      expect(called, isFalse);
    });

    test('自家 host 會帶憑證下載', () async {
      String? seen;
      MoodleWebApiConnector.fileDownloader =
          (url, savePath, {cancelToken, onProgress}) async => seen = url;

      expect(
        await MoodleWebApiConnector.downloadFileTo(
            'https://moodle2.ntust.edu.tw/webservice/pluginfile.php/1/x.pdf',
            '${tempDir.path}/x.pdf'),
        isTrue,
      );
      expect(seen, contains('token'));
    });

    test('下載失敗回 false 而不是拋', () async {
      MoodleWebApiConnector.fileDownloader = (url, savePath,
              {cancelToken, onProgress}) async =>
          throw Exception('boom');

      expect(
          await MoodleWebApiConnector.downloadFileTo(
              'https://moodle2.ntust.edu.tw/webservice/pluginfile.php/1/x.pdf',
              '${tempDir.path}/x.pdf'),
          isFalse);
    });
  });
}
