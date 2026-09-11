import 'dart:collection';

import 'package:logger/logger.dart';

/// Log 的環形緩衝與 [LogOutput] 實作。
///
/// 不可依賴 lib/ui：[Log] 幾乎被所有下層 import，這裡一旦牽進 log_console
/// 頁面（含 ansi_parser 與 Flutter），整包 UI 就會被拖進所有下層。
class LogBuffer {
  LogBuffer._();

  static final ListQueue<OutputEvent> events = ListQueue();
  static int _bufferSize = 50;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static void init({int bufferSize = 50}) {
    if (_initialized) return;
    _bufferSize = bufferSize;
    _initialized = true;
  }

  static void add(OutputEvent event) {
    if (events.length == _bufferSize) {
      events.removeFirst();
    }
    events.add(event);
  }

  static void clear() => events.clear();

  /// 取出緩衝內的錯誤訊息，供回饋表單附帶。最長 2000 字。
  static String getLog() {
    bool error = false;
    String log = "";
    for (final event in events.toList()) {
      if (event.level == Level.error) {
        error = true;
        log += event.lines.join("\n");
      }
    }
    if (!error) return "沒有任何錯誤";

    log = log.replaceAll(
        "┌───────────────────────────────────────────────────────────", "");
    log = log.replaceAll(
        "└───────────────────────────────────────────────────────────", "");
    log = log.replaceAll(
        "├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄", "");
    log = log.replaceAll("├", "");
    log = log.replaceAll("│", "");
    return log.substring(0, (log.length > 2000) ? 2000 : log.length);
  }
}

class MyConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // 這個類別就是 Log 的 console 輸出端，print 正是它的職責。
    // release 版由 MyLogFilter 擋在 error 以上，不會有一般訊息流出。
    // ignore: avoid_print
    event.lines.forEach(print);
    LogBuffer.add(event);
  }
}
