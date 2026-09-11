//
//  connector.dart
//  北科課程助手
//
//  Created by morris13579 on 2020/02/12.
//  Copyright © 2020 morris13579 All rights reserved.
//

import 'package:dio/dio.dart';

import 'connector_parameter.dart';
import 'dio_connector.dart';

class Connector {
  /// 這四個包裝必須保留 `async`。
  ///
  /// `DioConnector.instance` 是惰性初始化的，少了 `async`，它的例外會從
  /// rejected Future 變成**同步** throw；而 `privacy_policy_page.dart` 是在
  /// `build()` 裡把回傳值當 `FutureBuilder.future` 用的，同步 throw 會直接
  /// 炸掉 build。
  static Future<dynamic> getJsonByPost(ConnectorParameter parameter) async {
    final result = await DioConnector.instance.getDataByPostResponse(parameter);
    return result.data;
  }

  static Future<String> getDataByGet(ConnectorParameter parameter) async =>
      DioConnector.instance.getDataByGet(parameter);

  static Future<Response> getDataByGetResponse(
          ConnectorParameter parameter) async =>
      DioConnector.instance.getDataByGetResponse(parameter);

  static Future<Response> getDataByPostResponse(
          ConnectorParameter parameter) async =>
      DioConnector.instance.getDataByPostResponse(parameter);

  /// 回傳的是 body，不是 Response：webservice/upload.php 一律回 HTTP 200，
  /// 而且因為 `$_FILES` 非空，Content-Type 是 text/plain，Dio 不會 jsonDecode，
  /// 所以這裡拿到的是 String，解析交給呼叫端。
  static Future<dynamic> postMultipart(
    ConnectorParameter parameter, {
    required FormData formData,
    Duration? sendTimeout,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final result = await DioConnector.instance.postMultipart(
      parameter,
      formData: formData,
      sendTimeout: sendTimeout,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    return result.data;
  }

  static String uriAddQuery(String url, Map<String, dynamic> queryParameters) {
    if (!url.contains('?')) {
      url += "?";
    }
    for (var i in queryParameters.keys) {
      url += '&$i=${queryParameters[i]}';
    }
    return url;
  }
}
