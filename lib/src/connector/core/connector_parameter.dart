//
//  connector_parameter.dart
//
//  Created by morris13579 on 2020/02/12.
//  Copyright © 2020 morris13579 All rights reserved.
//

const presetCharsetName = 'utf-8';

class ConnectorParameter {
  static String presetUserAgent =
      "Mozilla/5.0 (iPhone; CPU iPhone OS 12_1_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Mobile/15E148 Safari/604.1";

  String url;
  dynamic data;
  String charsetName = presetCharsetName; //可設 'big5'
  String userAgent = presetUserAgent;
  String? referer;
  Map<String, dynamic>? headers;

  /// 要不要讓底層自己跟著 302 跑。
  ///
  /// **需要 cookie 的轉址鏈一律要關掉。** Dio 的自動轉址是交給 dart:io 的
  /// `HttpClient` 做的，而攔截器（含 `CookieManager`）只在最外層那一次請求
  /// 跑一遍：中途每一站既不會被帶上該站的 cookie，回應裡的 `Set-Cookie`
  /// 也不會被存起來。跨主機的登入交握會因此安靜地失敗——看起來就像「憑證
  /// 過期」。關掉之後由呼叫端自己一站一站走，每一站都會經過攔截器。
  bool followRedirects;

  ConnectorParameter(
    this.url, {
    this.data,
    this.referer,
    this.headers,
    this.followRedirects = true,
  });
}
