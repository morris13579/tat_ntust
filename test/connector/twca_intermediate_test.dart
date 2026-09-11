import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/io.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/connector/core/twca_intermediate.dart';
import 'package:flutter_test/flutter_test.dart';

/// 內建憑證的守門測試。
///
/// 這裡守的不是「解析對不對」，是「貼進來的東西還是不是那一張」。內建
/// 憑證的失敗模式很安靜：少一行 base64、換成別張、或哪天過期，程式都還是
/// 編得過、跑得動，只有實機上的行事曆頁會打不開。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 憑證的到期日。
  ///
  /// 這是手抄的，但抄得安全：下面的指紋測試已經把「內建的是哪一張憑證」
  /// 釘死了，所以只要指紋沒變，這個日期就還是那張憑證的 notAfter。
  ///
  /// ```bash
  /// curl -sS http://sslserver.twca.com.tw/cacert/secure_sha2_2023G3.crt \
  ///   | openssl x509 -inform DER -noout -dates
  /// ```
  final expiry = DateTime.utc(2030, 10, 16, 15, 59, 59);

  List<int> decodeDer() {
    final body = twcaSecureSslIntermediatePem
        .replaceAll('-----BEGIN CERTIFICATE-----', '')
        .replaceAll('-----END CERTIFICATE-----', '')
        .replaceAll(RegExp(r'\s'), '');
    return base64.decode(body);
  }

  test('內建的是 TWCA Secure SSL CA 那一張，一個 byte 都沒差', () {
    expect(
      sha256.convert(decodeDer()).toString(),
      twcaSecureSslIntermediateSha256,
      reason: '指紋對不上。內建憑證被換掉或貼漏了，行事曆頁會再次 '
          'CERTIFICATE_VERIFY_FAILED。重新從 AIA 網址抓一份：\n'
          'curl -sS http://sslserver.twca.com.tw/cacert/secure_sha2_2023G3.crt '
          '| openssl x509 -inform DER',
    );
  });

  test('SecurityContext 收得下這張憑證', () {
    // setTrustedCertificatesBytes 對格式很挑（PEM 前後綴、換行都要對）。
    // 上面的指紋測試只驗 base64 內容，驗不到外面那層包裝。
    expect(
      () => SecurityContext(withTrustedRoots: false)
          .setTrustedCertificatesBytes(
              utf8.encode(twcaSecureSslIntermediatePem)),
      returnsNormally,
    );
  });

  test('憑證還沒過期', () {
    expect(
      DateTime.now().toUtc().isBefore(expiry),
      isTrue,
      reason: '內建的中介憑證已於 $expiry 過期，行事曆頁會再次打不開。'
          '到 http://sslserver.twca.com.tw/cacert/ 換一張新的中介憑證，'
          '同時更新 twcaSecureSslIntermediateSha256 與本測試的 expiry。',
    );
  });

  test('Dio 真的走裝了這張憑證的 HttpClient', () {
    // 守的是「有人重構掉 DioConnector constructor 裡那三行」。憑證貼得再對，
    // 沒接上 adapter 也是白搭，而且同樣不會有任何編譯期徵兆。
    expect(DioConnector.instance.dio.httpClientAdapter,
        isA<IOHttpClientAdapter>());
    expect(DioConnector.securityContext, isNotNull);
  });
}
