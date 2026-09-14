import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_app/src/connector/interceptors/redacting_log_interceptor.dart';

/// 開發者選單看得到的最近幾筆 HTTP 請求。只在 debug 建置掛上，秘密照
/// [RedactingLogInterceptor] 遮掉——原生版看不到 alice 的 Flutter 介面，這一份是它的替代。
class HttpCallLog extends Interceptor {
  HttpCallLog._();

  static final HttpCallLog instance = HttpCallLog._();

  static const int capacity = 100;
  static const int _bodyLimit = 20000;
  static const String _extraKey = 'tat_http_call';

  final List<HttpCallRecord> _calls = [];
  var _nextId = 1;

  /// 新的在前。
  List<HttpCallRecord> get calls => _calls.reversed.toList();

  void clear() => _calls.clear();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final record = HttpCallRecord(
      id: _nextId++,
      method: options.method,
      url: RedactingLogInterceptor.redactUri(options.uri),
      startedAt: DateTime.now(),
      requestHeaders:
          _lines(RedactingLogInterceptor.redactHeaders(options.headers)),
      requestBody: _text(RedactingLogInterceptor.redactBody(options.data)),
    );
    options.extra[_extraKey] = record;
    _calls.add(record);
    if (_calls.length > capacity) _calls.removeAt(0);
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    final record = response.requestOptions.extra[_extraKey];
    if (record is HttpCallRecord) {
      record
        ..status = response.statusCode
        ..duration = DateTime.now().difference(record.startedAt)
        ..responseHeaders = _lines(
            RedactingLogInterceptor.redactHeaders(response.headers.map))
        ..responseBody = _responseText(response.data);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final record = err.requestOptions.extra[_extraKey];
    if (record is HttpCallRecord) {
      record
        ..status = err.response?.statusCode
        ..duration = DateTime.now().difference(record.startedAt)
        ..error = '${err.type.name} ${err.message ?? ''}'.trim();
    }
    handler.next(err);
  }

  static String _lines(Map<String, Object?> headers) =>
      [for (final e in headers.entries) '${e.key}: ${e.value}'].join('\n');

  /// 回應的字串不整段遮：HTML 裡沒有密碼，遮掉就什麼都看不到了；JSON 照欄位名遮。
  static String? _responseText(Object? data) {
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map || decoded is List) {
          return _text(RedactingLogInterceptor.redactBody(decoded));
        }
      } catch (_) {
        // 不是 JSON，照原文。
      }
      return _limit(data);
    }
    return _text(RedactingLogInterceptor.redactBody(data));
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    if (value is Map || value is List) {
      try {
        return _limit(const JsonEncoder.withIndent('  ').convert(value));
      } catch (_) {
        return _limit(value.toString());
      }
    }
    return _limit(value.toString());
  }

  static String _limit(String text) => text.length <= _bodyLimit
      ? text
      : '${text.substring(0, _bodyLimit)}…（共 ${text.length} 字元）';
}

class HttpCallRecord {
  HttpCallRecord({
    required this.id,
    required this.method,
    required this.url,
    required this.startedAt,
    required this.requestHeaders,
    this.requestBody,
  });

  final int id;
  final String method;
  final String url;
  final DateTime startedAt;
  final String requestHeaders;
  final String? requestBody;
  int? status;
  Duration? duration;
  String responseHeaders = '';
  String? responseBody;
  String? error;
}
