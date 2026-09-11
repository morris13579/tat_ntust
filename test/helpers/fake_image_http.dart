import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';

/// 1x1 的透明 PNG。
const String _transparentPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

/// 在「網路圖片都會成功」的環境下跑 [body]。
///
/// `AutomatedTestWidgetsFlutterBinding` 內建的 mock HttpClient 一律回 400，
/// 所以任何 `NetworkImage` 都會在測試裡拋圖片載入例外——那會蓋掉真正要驗的
/// 東西。這個 helper 換成一個永遠回 1x1 透明 PNG 的 client。
Future<T> withFakeImageHttp<T>(Future<T> Function() body) =>
    HttpOverrides.runZoned(body, createHttpClient: (_) => _FakeHttpClient());

/// 在「網路圖片一定失敗」的環境下跑 [body]。
///
/// 不能只靠 binding 內建那個一律回 400 的 mock client：`NetworkImage` 把
/// HttpClient 放在一個只建一次的 static 欄位裡，所以同一個檔案裡只要有任何
/// 一則先在 [withFakeImageHttp] 裡載過圖，之後每一則都會拿到那個「一定成功」
/// 的 client。`debugNetworkImageHttpClientProvider` 是繞過那顆 static 的
/// 官方掛鉤。
Future<T> withFailingImageHttp<T>(Future<T> Function() body) async {
  debugNetworkImageHttpClientProvider =
      () => _FakeHttpClient(statusCode: HttpStatus.notFound);
  try {
    return await body();
  } finally {
    debugNetworkImageHttpClientProvider = null;
  }
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({this.statusCode = HttpStatus.ok});

  final int statusCode;

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeHttpClientRequest(url, statusCode);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(url, statusCode);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} 沒有在假的 HttpClient 上實作');
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.uri, this.statusCode);

  @override
  final Uri uri;

  final int statusCode;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpClientResponse(statusCode);

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} 沒有在假的請求上實作');
}

class _FakeHttpClientResponse implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode);

  final List<int> _bytes = base64Decode(_transparentPngBase64);

  @override
  final int statusCode;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(_bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} 沒有在假的回應上實作');
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = -1;
  @override
  ContentType? contentType;
  @override
  DateTime? date;
  @override
  DateTime? expires;
  @override
  String? host;
  @override
  DateTime? ifModifiedSince;
  @override
  bool persistentConnection = true;
  @override
  int? port;

  @override
  List<String>? operator [](String name) => null;

  @override
  String? value(String name) => null;

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void remove(String name, Object value) {}

  @override
  void removeAll(String name) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  void noFolding(String name) {}

  @override
  void clear() {}
}
