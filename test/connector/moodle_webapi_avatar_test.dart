import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';

/// 換頭貼那兩趟請求的本機判讀規格。
///
/// 純解析（`decodeUploadBody` / `draftFileOf` / `updatePictureResultOf`）直接
/// 呼叫；送出那一段用 `wsPost` 與 `uploadPost` 換掉傳輸層，不碰網路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    resetAppStatics();
    MoodleWebApiConnector.wsToken = 'token-123';
    tempDir = Directory.systemTemp.createTempSync('avatar_test');
  });

  tearDown(() {
    resetAppStatics();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File makeFile([String name = 'pic.jpg']) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(List<int>.filled(64, 7));
    return file;
  }

  /// upload.php 成功時回的 $filerecord，欄位照抄自 webservice/upload.php。
  const String successBody = '['
      '{"component":"user","contextid":110,"userid":42,"filearea":"draft",'
      '"filename":"profile_picture.jpg","filepath":"/","itemid":614509342,'
      '"license":"unknown","author":"Wang Xiaoming",'
      r'"source":"O:8:\"stdClass\":1:{s:6:\"source\";s:19:\"profile_picture.jpg\";}",'
      '"filesize":184320}]';

  group('decodeUploadBody', () {
    test('String 會被 jsonDecode——upload.php 回的是 text/plain，Dio 不會替我們解', () {
      final decoded = MoodleWebApiConnector.decodeUploadBody(successBody);
      expect(decoded, isA<List<dynamic>>());
      expect((decoded as List).first['itemid'], 614509342);
    });

    test('已經是 List/Map 就原樣回', () {
      final list = [
        {'itemid': 1}
      ];
      expect(identical(MoodleWebApiConnector.decodeUploadBody(list), list),
          isTrue);
    });

    test('不是 JSON 的字串回 null（captive portal 的 HTML）', () {
      expect(MoodleWebApiConnector.decodeUploadBody('<html>hi</html>'), isNull);
    });
  });

  group('draftFileOf', () {
    test('成功的陣列解出 itemid，source 原樣留著不解析', () {
      final file = MoodleWebApiConnector.draftFileOf(successBody);
      expect(file.itemid, 614509342);
      expect(file.filename, 'profile_picture.jpg');
      expect(file.filesize, 184320);
      expect(file.isError, isFalse);
    });

    test('AJAX 例外包用的是 error 不是 message，moodleErrorOf 讀不到它', () {
      const body = '{"error":"Web service file upload must be enabled",'
          '"errorcode":"accessexception","stacktrace":null,"debuginfo":null,'
          '"reproductionlink":null}';

      // 先確認前提：共用的判讀點認不出這個形狀的訊息。
      final viaShared = MoodleWebApiConnector.moodleErrorOf(jsonDecode(body),
          wsFunction: 'upload.php');
      expect(viaShared?.message, isNull);

      expect(
        () => MoodleWebApiConnector.draftFileOf(body),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'accessexception')
            .having((e) => e.message, 'message',
                'Web service file upload must be enabled')),
      );
    });

    test('陣列裡的錯誤元素照樣是 HTTP 200，errortype 就是 errorcode', () {
      expect(
        () => MoodleWebApiConnector.draftFileOf(
            '[{"filename":"big.jpg","errortype":"fileoversized",'
            '"error":"The file is too big"}]'),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'fileoversized')),
      );
    });

    test('空陣列是 nofile', () {
      expect(
        () => MoodleWebApiConnector.draftFileOf('[]'),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'nofile')),
      );
    });
  });

  group('updatePictureResultOf', () {
    test('成功時帶著新網址', () {
      final result = MoodleWebApiConnector.updatePictureResultOf({
        'success': true,
        'profileimageurl':
            'https://moodle2.ntust.edu.tw/pluginfile.php/110/user/icon/boost/f1?rev=99',
        'warnings': <dynamic>[],
      });
      expect(result!.success, isTrue);
      expect(result.profileimageurl, contains('rev=99'));
    });

    test('success:false 沒有 profileimageurl（VALUE_OPTIONAL），不該拋', () {
      final result = MoodleWebApiConnector.updatePictureResultOf(
          {'success': false, 'warnings': <dynamic>[]});
      expect(result!.success, isFalse);
      expect(result.profileimageurl, '');
    });

    test('形狀不對回 null', () {
      expect(MoodleWebApiConnector.updatePictureResultOf('nope'), isNull);
      expect(MoodleWebApiConnector.updatePictureResultOf(const {}), isNull);
    });
  });

  group('uploadDraftFile', () {
    late List<ConnectorParameter> params;
    late List<FormData> bodies;

    void stubUpload(dynamic response) {
      params = [];
      bodies = [];
      MoodleWebApiConnector.uploadPost = (
        parameter, {
        required FormData formData,
        Duration? sendTimeout,
        ProgressCallback? onSendProgress,
        CancelToken? cancelToken,
      }) async {
        params.add(parameter);
        bodies.add(formData);
        return response;
      };
    }

    test('token 走 POST 欄位，網址上不帶任何 query', () async {
      stubUpload(successBody);

      final itemId = await MoodleWebApiConnector.uploadDraftFile(makeFile(),
          filename: 'profile_picture.jpg');

      expect(itemId, 614509342);
      // query string 會被寫進學校的 access log，長效憑證不能放在那裡。
      expect(params.single.url, MoodleWebApiConnector.uploadEndpoint);
      expect(params.single.url, isNot(contains('token')));
      expect(bodies.single.fields.map((e) => e.key), ['token']);
      expect(bodies.single.fields.single.value, 'token-123');
    });

    test('不送 itemid 也不送 filepath，讓伺服器開新的 draft 區', () async {
      stubUpload(successBody);
      await MoodleWebApiConnector.uploadDraftFile(makeFile(),
          filename: 'profile_picture.jpg');

      expect(bodies.single.fields.map((e) => e.key).toList(), ['token']);
    });

    test('檔案欄位叫 file_1，檔名照呼叫端指定的', () async {
      stubUpload(successBody);
      await MoodleWebApiConnector.uploadDraftFile(makeFile('原始檔名.HEIC'),
          filename: 'profile_picture.jpg');

      final files = bodies.single.files;
      expect(files, hasLength(1));
      expect(files.single.key, MoodleWebApiConnector.uploadFieldName);
      expect(files.single.value.filename, 'profile_picture.jpg');
    });

    test('沒有 token 就不送，回 null', () async {
      MoodleWebApiConnector.wsToken = null;
      stubUpload(successBody);

      expect(
          await MoodleWebApiConnector.uploadDraftFile(makeFile(),
              filename: 'a.jpg'),
          isNull);
      expect(params, isEmpty);
    });

    test('錯誤會往上拋，不像讀取路徑那樣吞掉', () async {
      stubUpload('[{"filename":"big.jpg","errortype":"fileoversized",'
          '"error":"too big"}]');

      expect(
        () => MoodleWebApiConnector.uploadDraftFile(makeFile(),
            filename: 'a.jpg'),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'fileoversized')),
      );
    });
  });

  group('updateProfilePicture', () {
    late List<ConnectorParameter> sent;

    void stubWs(dynamic response) {
      sent = [];
      MoodleWebApiConnector.wsPost = (parameter) async {
        sent.add(parameter);
        return response;
      };
    }

    test('移除時照樣送 draftitemid=0，而且不送 userid', () async {
      stubWs({'success': true, 'profileimageurl': '', 'warnings': <dynamic>[]});

      await MoodleWebApiConnector.updateProfilePicture(
          draftItemId: 0, delete: true);

      final data = sent.single.data!;
      expect(data['wsfunction'], MoodleWebApiConnector.updatePictureFunction);
      expect(data['draftitemid'], '0');
      expect(data['delete'], '1');
      // 這一支真的把 0 當成自己，所以乾脆不送。
      expect(data.containsKey('userid'), isFalse);
    });

    test('上傳時 delete 是 0', () async {
      stubWs(
          {'success': true, 'profileimageurl': 'x', 'warnings': <dynamic>[]});
      await MoodleWebApiConnector.updateProfilePicture(draftItemId: 99);
      expect(sent.single.data!['draftitemid'], '99');
      expect(sent.single.data!['delete'], '0');
    });

    test('站台沒開放這個 function 時在送出前就擋下來', () async {
      MoodleWebApiConnector.siteInfo = MoodleProfileEntity(functions: [
        MoodleProfileFunctions(name: 'core_webservice_get_site_info'),
      ]);
      stubWs({'success': true, 'warnings': <dynamic>[]});

      expect(
        () => MoodleWebApiConnector.updateProfilePicture(draftItemId: 0),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'accessexception')
            .having((e) => e.skippedBeforeRequest, 'skipped', isTrue)),
      );
      expect(sent, isEmpty);
    });

    test('invalidtoken 送得到 onApiError，而且照樣往上拋', () async {
      final seen = <MoodleApiException>[];
      MoodleWebApiConnector.onApiError = seen.add;
      stubWs({
        'exception': 'moodle_exception',
        'errorcode': 'invalidtoken',
        'message': 'Invalid token',
      });

      await expectLater(
        MoodleWebApiConnector.updateProfilePicture(draftItemId: 0),
        throwsA(isA<MoodleApiException>()
            .having((e) => e.errorcode, 'errorcode', 'invalidtoken')),
      );
      expect(seen.single.isInvalidToken, isTrue);
    });
  });
}
