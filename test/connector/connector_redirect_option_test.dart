import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_test/flutter_test.dart';

/// `followRedirects` 的預設值就是既有行為，加這個參數不動任何既有呼叫端。
void main() {
  test('預設跟著轉址跑', () {
    expect(ConnectorParameter('https://example.com').followRedirects, isTrue);
  });

  test('需要 cookie 的交握把它關掉', () {
    // 關掉之後由呼叫端自己一站一站走，每一站才會經過 CookieManager。
    // 為什麼非這樣不可，見 ClassroomConnector._follow 的說明。
    final parameter =
        ConnectorParameter('https://example.com', followRedirects: false);
    expect(parameter.followRedirects, isFalse);
  });
}
