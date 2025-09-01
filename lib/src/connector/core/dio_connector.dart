import 'dart:io';
import 'dart:typed_data';

import 'package:alice_lightweight/alice.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:fk_user_agent/fk_user_agent.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/connector/interceptors/request_interceptor.dart';
import 'package:get/get.dart' as get_utils;
import 'package:path_provider/path_provider.dart';

import 'connector_parameter.dart';

typedef SavePathCallback = String Function(Headers responseHeaders);

class DioConnector {
  static bool isInit = false;
  static final Map<String, String> _headers = {
    "Upgrade-Insecure-Requests": "1",
  };

  Alice alice = Alice(
    darkTheme: true,
  );

  static final BaseOptions dioOptions = BaseOptions(
      connectTimeout: const Duration(milliseconds: 10000),
      receiveTimeout: const Duration(milliseconds: 100000),
      sendTimeout: const Duration(milliseconds: 5000),
      headers: _headers,
      responseType: ResponseType.json,
      contentType: "application/x-www-form-urlencoded",
      validateStatus: (status) {
        // 關閉狀態檢測
        return status! <= 500;
      },
      responseDecoder: null);
  Dio dio = Dio(dioOptions);
  late PersistCookieJar _cookieJar;
  static final Exception connectorError =
      Exception("Connector statusCode is not 200");

  DioConnector._privateConstructor();

  static final DioConnector instance = DioConnector._privateConstructor();

  Future<void> init() async {
    if (isInit) return;
    try {
      Directory appDocDir = await getApplicationSupportDirectory();
      String appDocPath = appDocDir.path;
      _cookieJar =
          PersistCookieJar(storage: FileStorage("$appDocPath/.cookies/"));
      alice.setNavigatorKey(get_utils.Get.key);
      dio.interceptors.add(CookieManager(_cookieJar));
      dio.interceptors.add(RequestInterceptors());
      dio.interceptors.add(alice.getDioInterceptor());
      await FkUserAgent.init();
      if (FkUserAgent.webViewUserAgent != null) {
        Log.d("Set User Agent to\n${FkUserAgent.webViewUserAgent!}");
        ConnectorParameter.presetUserAgent = FkUserAgent.webViewUserAgent!;
      }
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
    }
    isInit = true;
  }

  void deleteCookies() {
    _cookieJar.deleteAll();
  }

  Future<String> getDataByPost(ConnectorParameter parameter) async {
    try {
      var response = await getDataByPostResponse(parameter);
      if (response.statusCode == HttpStatus.ok) {
        return response.toString();
      } else {
        throw connectorError;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> getDataByGet(ConnectorParameter parameter) async {
    try {
      var response = await getDataByGetResponse(parameter);
      if (response.statusCode == HttpStatus.ok) {
        return response.toString();
      } else {
        throw connectorError;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, List<String>>> getHeadersByGet(
      ConnectorParameter parameter) async {
    try {
      var response = await dio.get<ResponseBody>(
        parameter.url,
        options: Options(
            responseType: ResponseType.stream), // set responseType to `stream`
      ); //使速度更快
      if (response.statusCode == HttpStatus.ok) {
        return response.headers.map;
      } else {
        throw connectorError;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> getDataByGetResponse(ConnectorParameter parameter) async {
    Response response;
    try {
      String url = parameter.url;
      Map<String, String>? data = parameter.data;
      _handleCharsetName(parameter.charsetName);
      _handleHeaders(parameter);
      response = await dio.get(url, queryParameters: data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Uint8List?> getData(ConnectorParameter parameter) async {
    try {
      String url = parameter.url;
      dio.interceptors.add(CookieManager(_cookieJar));
      var response = await dio.get<Uint8List>(url, options: Options(
        responseType: ResponseType.bytes,
      ));

      return response.data;
    } catch (_) {
      rethrow;
    }
  }

  Future<Response> getDataByPostResponse(ConnectorParameter parameter) async {
    Response response;
    try {
      String url = parameter.url;
      _handleCharsetName(parameter.charsetName);
      _handleHeaders(parameter);
      response = await dio.post(url, data: parameter.data);
      return response;
    } catch (e) {
      rethrow;
    }
  }

  void _handleHeaders(ConnectorParameter parameter) {
    dio.options.headers[HttpHeaders.userAgentHeader] = parameter.userAgent;
    if (parameter.referer != null) {
      dio.options.headers[HttpHeaders.refererHeader] = parameter.referer;
    }
  }

  void _handleCharsetName(String charsetName) {
    if (charsetName == presetCharsetName) {
      dio.options.responseType = ResponseType.json;
    } else if (charsetName == 'big5') {
      dio.options.responseType = ResponseType.bytes;
    } else {
      dio.options.responseType = ResponseType.json;
    }
  }

  Future<void> download(String url, SavePathCallback savePath,
      {ProgressCallback? progressCallback,
      CancelToken? cancelToken,
      Map<String, dynamic>? header}) async {
    await dio
        .downloadUri(Uri.parse(url), savePath,
            onReceiveProgress: progressCallback,
            cancelToken: cancelToken,
            options: Options(receiveTimeout: Duration.zero, headers: header)) //設置不超時
        .catchError((onError, stack) {
      Log.eWithStack(onError.toString(), stack);
      throw onError;
    });
  }

  Map<String, String> get headers {
    return _headers;
  }

  PersistCookieJar get cookiesManager {
    return _cookieJar;
  }
}
