import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/store/moodle_session_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reset_statics.dart';

/// 把 Dio 的 HttpClientAdapter 換掉，記下**真正要送上線**的 headers 與 body。
///
/// moodle_autologin_url_test 在 `wsPost` 這一層作假，驗的是 connector 塞給
/// ConnectorParameter 的東西；這裡多走一段 `DioConnector._handleHeaders`，
/// 確認 UA 真的進了 request header、privatetoken 真的在 POST body 而不在
/// query string（Moodle 看到它出現在 `$_GET` 會直接回 invalidprivatetoken）。
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<Object> responses;

  _RecordingAdapter(List<Object> responses)
      : responses = List<Object>.from(responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(responses.removeAt(0)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const moodleUrl =
      'https://moodle2.ntust.edu.tw/mod/assign/view.php?id=123&lang=zh_tw';
  const keyOk = {
    'key': '5f3c8a1b2d4e6f7a8b9c0d1e2f3a4b5c',
    'autologinurl':
        'https://moodle2.ntust.edu.tw/admin/tool/mobile/autologin.php',
    'warnings': <dynamic>[],
  };
  const siteInfoBody = {
    'userid': 12345,
    'fullname': 'Test',
    'functions': [
      {'name': 'tool_mobile_get_autologin_key', 'version': '2024100700'},
    ],
  };

  late HttpClientAdapter originalAdapter;

  setUp(() {
    resetAppStatics();
    originalAdapter = DioConnector.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    // DioConnector.instance 是 process 級單例，adapter 一定要還原。
    DioConnector.instance.dio.httpClientAdapter = originalAdapter;
    resetAppStatics();
  });

  /// Dio 的 header key 大小寫不一定，照 HTTP 的語意不分大小寫找。
  String? userAgentOf(RequestOptions request) {
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == 'user-agent') {
        return entry.value?.toString();
      }
    }
    return null;
  }

  test('autologin 那一個請求的 header 帶 MoodleMobile，下一個請求就沒有', () async {
    final adapter = _RecordingAdapter([keyOk, siteInfoBody]);
    DioConnector.instance.dio.httpClientAdapter = adapter;
    await MoodleSessionStore.instance
        .save(MoodleTokenEntity('sig', 'ws-token', 'priv-token'));
    MoodleWebApiConnector.wsToken = 'ws-token';
    MoodleWebApiConnector.userId = '12345';

    final result = await MoodleWebApiConnector.autologinUrl(moodleUrl);
    await MoodleWebApiConnector.getProfile();

    expect(Uri.parse(result).queryParameters['urltogo'], moodleUrl);
    expect(adapter.requests, hasLength(2));

    final autologin = adapter.requests[0];
    expect(autologin.method, 'POST');
    expect(autologin.uri.toString(),
        '${MoodleWebApiConnector.host}/webservice/rest/server.php');
    expect(userAgentOf(autologin), contains('MoodleMobile'));
    expect(
        userAgentOf(autologin), startsWith(ConnectorParameter.presetUserAgent));
    // privatetoken 只能在 body；query string 裡有它 Moodle 會直接拒絕。
    expect(autologin.data, containsPair('privatetoken', 'priv-token'));
    expect(autologin.uri.queryParameters, isNot(contains('privatetoken')));

    final profile = adapter.requests[1];
    expect(userAgentOf(profile), ConnectorParameter.presetUserAgent);
    expect(userAgentOf(profile), isNot(contains('MoodleMobile')));
    expect(ConnectorParameter.presetUserAgent, contains('Safari/604.1'));
  });
}
