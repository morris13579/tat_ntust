import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// 檔案網址帶憑證的規格。
///
/// 優先走 `tokenpluginfile.php/<userprivateaccesskey>/…`，那把鑰匙只能取檔案。
/// `?token=<wsToken>` 是退路：那顆 token 能呼叫全部 web service，卻會留在圖片
/// 的 src、WebView 歷史與轉址的 Referer 裡。站台可以停用 tokenpluginfile.php，
/// 所以要先探測。
void main() {
  const wsToken = 'ws-token-aaaaaaaaaaaaaaaaaaaaaaaa';
  const accessKey = 'ffffffffffffffffffffffffffffffff';
  const fileUrl = '${MoodleWebApiConnector.host}'
      '/webservice/pluginfile.php/12345/mod_resource/content/1/lecture.pdf';

  final defaultProber = MoodleWebApiConnector.tokenPluginFileProber;

  void reset() {
    MoodleWebApiConnector.tokenPluginFileProber = defaultProber;
    MoodleWebApiConnector.resetTokenPluginFileProbe();
    // wsToken 的 setter 會順手清掉 siteInfo，所以它要先設。
    MoodleWebApiConnector.wsToken = null;
    MoodleWebApiConnector.siteInfo = null;
    MoodleWebApiConnector.userId = null;
  }

  setUp(reset);
  tearDown(reset);

  void loginAs({String key = accessKey}) {
    MoodleWebApiConnector.wsToken = wsToken;
    MoodleWebApiConnector.siteInfo =
        MoodleProfileEntity.fromJson({'userprivateaccesskey': key});
  }

  /// 探測回 [works]；[calls] 記錄被探測過幾次、探的是哪個網址。
  void stubProbe(bool works, List<String> calls) {
    MoodleWebApiConnector.tokenPluginFileProber = (url) async {
      calls.add(url);
      if (!works) throw Exception('site disabled tokenpluginfile.php');
      return true;
    };
  }

  test('還沒探測完之前先走舊的 ?token=，並在背景探一次', () async {
    final calls = <String>[];
    stubProbe(true, calls);
    loginAs();

    final first = MoodleWebApiConnector.fileUrlWithToken(fileUrl);

    expect(first, contains('token=$wsToken'));
    expect(first, isNot(contains('tokenpluginfile')));
    await MoodleWebApiConnector.tokenPluginFileProbe;
    // 探測用的就是正在改寫的那個網址（官方 App 也是這樣 HEAD 一次）。
    expect(calls.single, contains('/tokenpluginfile.php/$accessKey/'));
  });

  test('探測成功之後改走 tokenpluginfile，網址裡不再有 wsToken', () async {
    final calls = <String>[];
    stubProbe(true, calls);
    loginAs();

    MoodleWebApiConnector.fileUrlWithToken(fileUrl);
    await MoodleWebApiConnector.tokenPluginFileProbe;
    final second = MoodleWebApiConnector.fileUrlWithToken(fileUrl);

    expect(
      second,
      '${MoodleWebApiConnector.host}/tokenpluginfile.php/$accessKey'
      '/12345/mod_resource/content/1/lecture.pdf',
    );
    expect(second, isNot(contains(wsToken)));
  });

  test('探測失敗就一直留在舊路徑，附件不會整批打不開', () async {
    final calls = <String>[];
    stubProbe(false, calls);
    loginAs();

    MoodleWebApiConnector.fileUrlWithToken(fileUrl);
    await MoodleWebApiConnector.tokenPluginFileProbe;
    final second = MoodleWebApiConnector.fileUrlWithToken(fileUrl);

    expect(MoodleWebApiConnector.tokenPluginFileWorks, isFalse);
    expect(second, contains('token=$wsToken'));
    expect(second, isNot(contains('tokenpluginfile')));
  });

  test('探測只做一次，之後不再重複打', () async {
    final calls = <String>[];
    stubProbe(true, calls);
    loginAs();

    MoodleWebApiConnector.fileUrlWithToken(fileUrl);
    MoodleWebApiConnector.fileUrlWithToken(fileUrl);
    await MoodleWebApiConnector.tokenPluginFileProbe;
    MoodleWebApiConnector.fileUrlWithToken(fileUrl);
    await MoodleWebApiConnector.tokenPluginFileProbe;

    expect(calls, hasLength(1));
  });

  test('accessKey 為空時不探測，直接走舊路徑', () async {
    final calls = <String>[];
    stubProbe(true, calls);
    // site_info 拿不到（或站台沒送 userprivateaccesskey）就是這個形狀。
    loginAs(key: '');

    final url = MoodleWebApiConnector.fileUrlWithToken(fileUrl);

    expect(url, contains('token=$wsToken'));
    expect(calls, isEmpty);
    expect(MoodleWebApiConnector.tokenPluginFileProbe, isNull);
  });

  test('外站網址兩條路徑都不加憑證（既有的同站檢查對新路徑一樣有效）', () async {
    final calls = <String>[];
    stubProbe(true, calls);
    loginAs();
    MoodleWebApiConnector.tokenPluginFileWorks = true;

    const foreign =
        'https://evil.example.com/webservice/pluginfile.php/1/x/lecture.pdf';
    final url = MoodleWebApiConnector.fileUrlWithToken(foreign);

    expect(url, foreign);
    expect(url, isNot(contains(accessKey)));
    expect(url, isNot(contains(wsToken)));
    expect(calls, isEmpty);
  });

  test('退路要換成 webservice/pluginfile.php——pluginfile.php 不吃 token', () async {
    final calls = <String>[];
    stubProbe(true, calls);
    loginAs();
    // stored_file_exporter 給的形狀（討論區的附件與內嵌圖片就是這一種）。
    const exporterUrl = '${MoodleWebApiConnector.host}'
        '/pluginfile.php/8801/mod_forum/post/951/scope.png?forcedownload=1';

    final url = MoodleWebApiConnector.fileUrlWithToken(exporterUrl);

    // pluginfile.php 走的是瀏覽器 session，帶著 token 一樣被踢去登入頁。
    expect(
        url,
        startsWith('${MoodleWebApiConnector.host}'
            '/webservice/pluginfile.php/8801/mod_forum/post/951/scope.png?'));
    expect(url, contains('forcedownload=1'));
    expect(url, contains('token=$wsToken'));
    await MoodleWebApiConnector.tokenPluginFileProbe;
  });

  test('已經是 webservice/pluginfile.php 的網址不重複改寫', () async {
    final calls = <String>[];
    stubProbe(true, calls);
    loginAs();

    final url = MoodleWebApiConnector.fileUrlWithToken(fileUrl);

    expect('/webservice/'.allMatches(url), hasLength(1));
    await MoodleWebApiConnector.tokenPluginFileProbe;
  });

  test('wsToken 是 null 時原樣回傳', () {
    MoodleWebApiConnector.siteInfo =
        MoodleProfileEntity.fromJson({'userprivateaccesskey': accessKey});
    MoodleWebApiConnector.tokenPluginFileWorks = true;

    expect(MoodleWebApiConnector.fileUrlWithToken(fileUrl), fileUrl);
  });

  group('tokenPluginFileUrl：路徑改寫', () {
    setUp(() => loginAs());

    test('query 原封不動帶著走（forcedownload 之類必須留著）', () {
      expect(
        MoodleWebApiConnector.tokenPluginFileUrl('$fileUrl?forcedownload=1'),
        '${MoodleWebApiConnector.host}/tokenpluginfile.php/$accessKey'
        '/12345/mod_resource/content/1/lecture.pdf?forcedownload=1',
      );
    });

    test('沒有 /webservice 前綴的 pluginfile.php 也改寫得到', () {
      expect(
        MoodleWebApiConnector.tokenPluginFileUrl(
            '${MoodleWebApiConnector.host}/pluginfile.php/1/x/a.png'),
        '${MoodleWebApiConnector.host}/tokenpluginfile.php/$accessKey'
        '/1/x/a.png',
      );
    });

    test('已經帶著 token 的網址不改寫，免得生出兩種憑證都在的怪網址', () {
      expect(
        MoodleWebApiConnector.tokenPluginFileUrl('$fileUrl?token=$wsToken'),
        isNull,
      );
    });

    test('不是 pluginfile 的網址不改寫', () {
      expect(
        MoodleWebApiConnector.tokenPluginFileUrl(
            '${MoodleWebApiConnector.host}/mod/forum/view.php?id=1'),
        isNull,
      );
    });
  });
}
