import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_test/flutter_test.dart';

/// 凍結 `Connector.uriAddQuery` 與 `ConnectorParameter` 的行為（含已知瑕疵）。
/// 其餘 `Connector.getDataByXxx` 都會走到 `DioConnector.instance`，而
/// `DioConnector.init` 依賴 path_provider，無法在此測。
void main() {
  group('Connector.uriAddQuery', () {
    test('網址不含 ? 時會產生 "?&key=value"（已知的外觀瑕疵）', () {
      // 先補上 "?" 再無條件用 "&" 串接，於是第一個參數前面多一個 "&"。
      // 伺服器多半能容忍，僅為外觀問題。
      expect(
        Connector.uriAddQuery(
            'https://moodle.ntust.edu.tw/mod/page/view.php', {'lang': 'zh_tw'}),
        'https://moodle.ntust.edu.tw/mod/page/view.php?&lang=zh_tw',
      );
    });

    test('網址已含 query 時，直接以 & 串接（正常情況）', () {
      expect(
        Connector.uriAddQuery(
            'https://moodle.ntust.edu.tw/view.php?id=123', {'lang': 'en'}),
        'https://moodle.ntust.edu.tw/view.php?id=123&lang=en',
      );
    });

    test('網址只以 ? 結尾時不會再補 ?，但仍多一個 &', () {
      expect(
        Connector.uriAddQuery('https://example.com/a?', {'k': 'v'}),
        'https://example.com/a?&k=v',
      );
    });

    test('多個參數依 Map 的插入順序串接', () {
      expect(
        Connector.uriAddQuery('https://example.com/a', {'b': '1', 'a': '2'}),
        'https://example.com/a?&b=1&a=2',
      );
    });

    test('空的參數表仍會在網址尾端留下一個 ?（已知瑕疵）', () {
      expect(
        Connector.uriAddQuery('https://example.com/a', {}),
        'https://example.com/a?',
      );
    });

    test('已含 ? 且參數表為空時，網址原樣返回', () {
      expect(
        Connector.uriAddQuery('https://example.com/a?id=1', {}),
        'https://example.com/a?id=1',
      );
    });

    test('key 與 value 都不做 URL encode（已知問題）', () {
      // 直接字串內插，空白、& 與 = 原樣寫入，可能把單一參數切成多個。
      // 正解是改用 Uri.replace(queryParameters:)。
      expect(
        Connector.uriAddQuery('https://example.com/s', {'q': 'a b&c=d'}),
        'https://example.com/s?&q=a b&c=d',
      );
    });

    test('非字串的 value 以 toString() 內插，null 會變成字面上的 "null"', () {
      expect(
        Connector.uriAddQuery('https://example.com/a', {
          'page': 1,
          'flag': true,
          'none': null,
        }),
        'https://example.com/a?&page=1&flag=true&none=null',
      );
    });

    test('fragment 之後才接 query，產生不合法的網址（已知問題）', () {
      // 只看有沒有 "?"，不理會 "#"，所以參數會被塞進 fragment 裡。
      expect(
        Connector.uriAddQuery('https://example.com/a#section', {'k': 'v'}),
        'https://example.com/a#section?&k=v',
      );
    });

    test('fragment 內出現的 ? 也算數，導致不再補 ?（已知問題）', () {
      expect(
        Connector.uriAddQuery('https://example.com/a#q?z', {'k': 'v'}),
        'https://example.com/a#q?z&k=v',
      );
    });
  });

  group('ConnectorParameter 建構', () {
    test('預設值：utf-8 編碼、preset UA、referer 與 headers 為 null', () {
      final p = ConnectorParameter('https://example.com');
      expect(p.url, 'https://example.com');
      expect(p.data, isNull);
      expect(p.referer, isNull);
      expect(p.headers, isNull);
      expect(p.charsetName, presetCharsetName);
      expect(presetCharsetName, 'utf-8');
      expect(p.userAgent, ConnectorParameter.presetUserAgent);
    });

    test('具名參數 data / referer / headers 會原樣指派', () {
      final headers = {'X-Test': '1'};
      final p = ConnectorParameter(
        'https://example.com',
        data: {'account': 'B10000000'},
        referer: 'https://ref.example.com',
        headers: headers,
      );
      expect(p.data, {'account': 'B10000000'});
      expect(p.referer, 'https://ref.example.com');
      expect(p.headers, headers);
    });

    test('headers 以參考存放，外部改動會影響 parameter（已知問題）', () {
      // 沒有複製一份，呼叫端之後修改同一個 Map 會意外改到請求標頭。
      final headers = <String, dynamic>{'X-Test': '1'};
      final p = ConnectorParameter('https://example.com', headers: headers);
      headers['X-Injected'] = '2';
      expect(p.headers, containsPair('X-Injected', '2'));
    });

    test('charsetName 與 userAgent 為可變欄位，可逐一覆寫', () {
      final p = ConnectorParameter('https://example.com');
      p.charsetName = 'big5';
      p.userAgent = 'custom-agent';
      expect(p.charsetName, 'big5');
      expect(p.userAgent, 'custom-agent');
      // 覆寫實例欄位不會動到 static
      expect(ConnectorParameter.presetUserAgent, isNot('custom-agent'));
    });
  });

  group('ConnectorParameter.presetUserAgent 這個 static 的外洩行為', () {
    late String original;

    setUp(() {
      original = ConnectorParameter.presetUserAgent;
    });

    tearDown(() {
      // 這是 process 級 static，測試之間會互相污染，一定要還原。
      ConnectorParameter.presetUserAgent = original;
    });

    test('預設值是硬編碼的 iPhone Safari UA', () {
      expect(ConnectorParameter.presetUserAgent,
          startsWith('Mozilla/5.0 (iPhone;'));
      expect(ConnectorParameter.presetUserAgent, contains('Safari/604.1'));
    });

    test('改寫 static 之後才建立的實例會拿到新值（DioConnector.init 就是這樣改的）', () {
      // dio_connector.dart 在 init 時把 FkUserAgent 的 WebView UA 寫進這個 static，
      // 於是「什麼時候建立 ConnectorParameter」會決定送出哪一個 UA。
      final before = ConnectorParameter('https://example.com');
      ConnectorParameter.presetUserAgent = 'patched-agent';
      final after = ConnectorParameter('https://example.com');

      expect(after.userAgent, 'patched-agent');
      // 已建立的實例維持舊值，兩者不一致
      expect(before.userAgent, original);
      expect(before.userAgent, isNot(after.userAgent));
    });
  });
}
