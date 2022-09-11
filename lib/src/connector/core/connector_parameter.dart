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
  String charsetName = presetCharsetName; //設定編碼預設utf-8 可以設定big5
  String userAgent = presetUserAgent;
  String? referer;

  ConnectorParameter(this.url, {this.data, this.referer});
}
