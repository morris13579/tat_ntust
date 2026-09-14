import 'dart:convert';

import 'package:flutter_app/debug/log/console_output.dart';
import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/connector/interceptors/http_call_log.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 原生版的開發者選單，照 `dev_page.dart` 與 `store_edit_page.dart`。
class DeveloperBridge implements TatDeveloperApi {
  const DeveloperBridge();

  static void install() => TatDeveloperApi.setUp(const DeveloperBridge());

  /// 這幾個 key 的值是憑證，不在編輯框裡回顯原文。
  static bool isSensitive(String key) =>
      key == 'user_data' || key == 'moodle_token';

  @override
  List<LogEntry> logs() => [
        for (final event in LogBuffer.events.toList().reversed)
          LogEntry(level: event.level.name, text: event.lines.join('\n')),
      ];

  @override
  void clearLogs() => LogBuffer.clear();

  @override
  List<HttpCallEntry> httpCalls() => [
        for (final call in HttpCallLog.instance.calls)
          HttpCallEntry(
            id: call.id,
            method: call.method,
            url: call.url,
            status: call.status,
            durationMs: call.duration?.inMilliseconds ?? -1,
            startedAt: call.startedAt.millisecondsSinceEpoch,
            requestHeaders: call.requestHeaders,
            requestBody: call.requestBody,
            responseHeaders: call.responseHeaders,
            responseBody: call.responseBody,
            error: call.error,
          ),
      ];

  @override
  void clearHttpCalls() => HttpCallLog.instance.clear();

  /// 快取排在最後：它們又多又長，要改的幾乎都是設定。
  @override
  Future<List<StoreEntry>> storeEntries() async {
    final pref = await SharedPreferences.getInstance();
    final keys = pref.getKeys().toList();
    return [
      for (final key in [
        ...keys.where((k) => !k.contains('cache_')),
        ...keys.where((k) => k.contains('cache_')),
      ])
        StoreEntry(
          key: key,
          value: isSensitive(key) ? '' : _pretty(pref.get(key)),
          editable: pref.get(key) is String || pref.get(key) is int,
          sensitive: isSensitive(key),
        ),
    ];
  }

  @override
  Future<void> setStoreValue(String key, String value) async {
    final pref = await SharedPreferences.getInstance();
    final current = pref.get(key);
    if (current is String) {
      await pref.setString(key, value);
    } else if (current is int) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) await pref.setInt(key, parsed);
    }
  }

  @override
  Future<void> removeStoreKey(String key) async {
    await (await SharedPreferences.getInstance()).remove(key);
  }

  @override
  Future<void> reloadStore() => Model.instance.getInstance();

  static String _pretty(Object? value) {
    final text = value.toString();
    try {
      return const JsonEncoder.withIndent('  ').convert(json.decode(text));
    } catch (_) {
      return text;
    }
  }
}
