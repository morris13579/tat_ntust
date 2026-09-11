import 'dart:io';

import 'package:dio/dio.dart';

class RequestInterceptors extends Interceptor {
  String referer = "https://i.ntust.edu.tw/student";

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.headers.containsKey(HttpHeaders.refererHeader)) {
      options.headers[HttpHeaders.refererHeader] = referer;
    }
    referer = options.uri.toString();
    handler.next(options);
  }
}
