import 'dart:convert';
import 'dart:io';

import 'package:alice_lightweight/alice.dart';
import 'package:flutter/foundation.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:fk_user_agent/fk_user_agent.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/connector/interceptors/redacting_log_interceptor.dart';
import 'package:flutter_app/src/connector/interceptors/request_interceptor.dart';
import 'package:flutter_app/src/connector/core/twca_intermediate.dart';
import 'package:get/get.dart' as get_utils;
import 'package:path_provider/path_provider.dart';

import 'connector_parameter.dart';

typedef SavePathCallback = String Function(Headers responseHeaders);

class DioConnector {
  static bool isInit = false;
  static final Map<String, String> _headers = {
    "Upgrade-Insecure-Requests": "1",
  };

  // alice 3.10 起 darkTheme 不再有作用，它改看 Theme.of(context).brightness。
  Alice alice = Alice();

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

  /// 型別刻意用介面 [CookieJar] 而不是實作 [PersistCookieJar]：呼叫端只用到
  /// loadForRequest / saveFromResponse / deleteAll，全在介面上，
  /// [cookieJarForTesting] 才塞得進不碰檔案系統的實作。
  late CookieJar _cookieJar;
  static final Exception connectorError =
      Exception("Connector statusCode is not 200");

  DioConnector._privateConstructor() {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient(context: securityContext),
    );
  }

  static final DioConnector instance = DioConnector._privateConstructor();

  /// Dart 內建的根憑證，外加 `www.academic.ntust.edu.tw` 少送的那一張中介
  /// 憑證（為什麼要補、為什麼不算放寬驗證，見 [twcaSecureSslIntermediatePem]）。
  ///
  /// 裝在 constructor 而不是 [init]：[init] 需要 path_provider 而且整段包在
  /// try/catch 裡，它失敗時 `dio` 照樣會被拿去用，那時候行事曆一樣該連得上。
  static final SecurityContext securityContext = buildSecurityContext();

  @visibleForTesting
  static SecurityContext buildSecurityContext() {
    final context = SecurityContext(withTrustedRoots: true);
    try {
      context.setTrustedCertificatesBytes(
          utf8.encode(twcaSecureSslIntermediatePem));
    } catch (e, stack) {
      // 憑證過期或內容壞掉時，只該讓行事曆那一頁連不上，不該讓整個 App
      // 失去網路——其他主機的憑證鏈本來就是完整的。
      Log.eWithStack(e.toString(), stack);
    }
    return context;
  }

  Future<void> init() async {
    if (isInit) return;
    try {
      Directory appDocDir = await getApplicationSupportDirectory();
      String appDocPath = appDocDir.path;
      _cookieJar =
          PersistCookieJar(storage: FileStorage("$appDocPath/.cookies/"));
      alice.setNavigatorKey(get_utils.Get.key);
      dio.interceptors.add(CookieManager(_cookieJar));
      if (kDebugMode) {
        // 用會遮蔽的版本取代 Dio 內建的 LogInterceptor：內建那個會把完整
        // cookie 與登入 POST 的明文密碼印進 logcat。
        //
        // alice 仍然把整段未遮蔽的請求常駐記憶體並可從 DevPage 匯出，那是
        // 第三方套件、改不動；它同樣只在 kDebugMode 下掛上。
        dio.interceptors.add(const RedactingLogInterceptor());
      }
      dio.interceptors.add(RequestInterceptors());
      if (kDebugMode) {
        dio.interceptors.add(alice.getDioInterceptor());
      }
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

  /// 測試用的注入點。正式環境的 jar 一律由 [init] 建立成 [PersistCookieJar]，
  /// 而 [init] 需要 path_provider，在 `flutter test` 裡跑不起來。
  @visibleForTesting
  set cookieJarForTesting(CookieJar jar) => _cookieJar = jar;

  /// 刪除全部 cookie。
  ///
  /// 一定要回傳 Future：[PersistCookieJar.deleteAll] 底下是非同步的檔案 I/O。
  /// 把它丟掉，登出流程 (`SessionCleaner.logoutAll`) 會在 cookie 檔還躺在
  /// 硬碟上時就往下走，而且刪除失敗永遠不會被呼叫端的 try/catch 看到。
  Future<void> deleteCookies() => _cookieJar.deleteAll();
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
            // 只讀回應標頭，不把內容下載下來
            responseType: ResponseType.stream),
      );
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
      var response = await dio.get<Uint8List>(url,
          options: Options(
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

  /// multipart POST。既有路徑走 [getDataByPostResponse]，那條路的逾時是
  /// BaseOptions 的 5 秒 sendTimeout；上傳一張照片撐不過去，而 sendTimeout 在
  /// IOHttpClientAdapter 是「送完整個 body 的總時間」，不是 chunk 間隔。
  /// Content-Type 與 Content-Length 由 Dio 依 FormData 覆寫，不必也不可以自己設。
  Future<Response> postMultipart(
    ConnectorParameter parameter, {
    required FormData formData,
    Duration? sendTimeout,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    _handleCharsetName(parameter.charsetName);
    _handleHeaders(parameter);
    return dio.post(
      parameter.url,
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      options: Options(sendTimeout: sendTimeout),
    );
  }

  void _handleHeaders(ConnectorParameter parameter) {
    dio.options.headers[HttpHeaders.userAgentHeader] = parameter.userAgent;
    if (parameter.referer != null) {
      dio.options.headers[HttpHeaders.refererHeader] = parameter.referer;
    }
    if (parameter.headers != null) {
      dio.options.headers.addAll(parameter.headers!);
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
            options: Options(
              receiveTimeout: Duration.zero, //設置不超時
              headers: header,
              // 共用的 validateStatus 放行到 500，下載時那等於把 404 的錯誤頁、
              // 維護頁與 PHP fatal 的 HTML 原封不動寫成檔案。非 2xx 一律當失敗。
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 300,
            ))
        .catchError((onError, stack) {
      Log.eWithStack(onError.toString(), stack);
      throw onError;
    });
  }

  CookieJar get cookiesManager {
    return _cookieJar;
  }
}
