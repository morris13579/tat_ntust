import 'package:dio/dio.dart';
import 'package:flutter_app/debug/log/log.dart';

/// 會遮蔽秘密的請求 log，取代 Dio 內建的 `LogInterceptor`。
///
/// 內建那個會逐條印出 request header 與 body，實測會把完整的 ssoam2 session
/// cookie、`AuthServer` token 與登入 POST 的明文密碼直接寫進 logcat——
/// debug build 上任何讀得到 logcat 的程式都拿得到。
///
/// 遮的是三類，逐一列舉而不是靠關鍵字猜：
/// - **header**：cookie / set-cookie / authorization
/// - **body 欄位**：password、wstoken、privatetoken、
///   `__RequestVerificationToken`
/// - **query 參數**：同上那組欄位名
///
/// 只遮值不遮鍵、印長度不印內容：「有沒有帶 cookie」「token 是不是空的」
/// 對除錯是必要的，值本身不是。
class RedactingLogInterceptor extends Interceptor {
  const RedactingLogInterceptor();

  static const Set<String> _sensitiveHeaders = {
    'cookie',
    'set-cookie',
    'authorization',
    'proxy-authorization',
  };

  static const Set<String> _sensitiveFields = {
    'password',
    'passwd',
    'wstoken',
    'privatetoken',
    'private_token',
    'token',
    '__requestverificationtoken',
  };

  /// 遮蔽後的替代字串，保留長度。
  static String mask(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '<空>';
    return '<已遮蔽 ${text.length} 字元>';
  }

  static bool _isSensitiveKey(String key, Set<String> against) =>
      against.contains(key.toLowerCase().trim());

  static Map<String, Object?> redactHeaders(Map<String, Object?> headers) => {
        for (final e in headers.entries)
          e.key: _isSensitiveKey(e.key, _sensitiveHeaders)
              ? mask(e.value)
              : e.value,
      };

  /// 遮蔽 body。
  ///
  /// **最外層是字串的話整個遮掉**：那種 body 無法逐欄位判斷，而登入請求的
  /// body 正好是 form-urlencoded 字串，寧可少印。這條規則只套用在最外層，
  /// Map 裡的字串值照鍵名判斷，否則帳號、課號這些不是秘密的欄位會一起被遮掉。
  static Object? redactBody(Object? data) {
    if (data is String) return mask(data);
    return _redactValue(data);
  }

  static Object? _redactValue(Object? data) {
    if (data == null) return null;
    // FormData 沒有 toString()，今天印出來只是 `Instance of 'FormData'`；
    // 那是巧合不是設計。明確只印欄位名與檔名，值一律不印。
    if (data is FormData) {
      return {
        'fields': data.fields.map((e) => e.key).toList(),
        'files': data.files.map((e) => e.value.filename).toList(),
      };
    }
    if (data is Map) {
      return {
        for (final e in data.entries)
          e.key: _isSensitiveKey(e.key.toString(), _sensitiveFields)
              ? mask(e.value)
              : _redactValue(e.value),
      };
    }
    if (data is List) return data.map(_redactValue).toList();
    return data;
  }

  /// 遮蔽網址的 query 參數，路徑保留。
  static String redactUri(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri.toString();
    final redacted = {
      for (final e in uri.queryParameters.entries)
        e.key:
            _isSensitiveKey(e.key, _sensitiveFields) ? mask(e.value) : e.value,
    };
    return uri.replace(queryParameters: redacted).toString();
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    Log.d('--> ${options.method} ${redactUri(options.uri)}\n'
        'headers: ${redactHeaders(options.headers)}\n'
        'body: ${redactBody(options.data)}');
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    Log.d('<-- ${response.statusCode} '
        '${redactUri(response.requestOptions.uri)}\n'
        'headers: ${redactHeaders(response.headers.map)}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    Log.d('<-- 錯誤 ${err.type} ${redactUri(err.requestOptions.uri)}\n'
        '${err.message}');
    handler.next(err);
  }
}
