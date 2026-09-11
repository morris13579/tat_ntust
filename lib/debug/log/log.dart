import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/debug/log/console_output.dart';
import 'package:logger/logger.dart';

enum LogMode { logError, logDebug }

/// release build 一律不輸出，只有錯誤例外。
///
/// 不可以改成無條件 `return true`：Log.d 的內容含帶 wsToken 的下載網址、
/// Moodle site_info 全文與含 Cookie 的 header，正式版照樣 print 等於任何
/// 拿得到 logcat 或 adb bugreport 的人都能複製 token 冒用帳號。
class MyLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      return event.level.index >= Level.error.index;
    }
    return true;
  }
}

class Log {
  static Logger logger = Logger(
    filter: MyLogFilter(),
    printer: PrettyPrinter(
        methodCount: 2,
        // number of method calls to be displayed
        errorMethodCount: 8,
        // number of method calls if stacktrace is provided
        lineLength: 60,
        // width of the output
        colors: true,
        // Colorful log messages
        printEmojis: false,
        // Print an emoji for each log message
        // printTime: false 的等價寫法
        dateTimeFormat: DateTimeFormat.none),
    output: MyConsoleOutput(),
  );

  static void init() {
    LogBuffer.init();
  }

  /// 錯誤回報的出口，預設送到 Crashlytics。
  ///
  /// 之所以做成可替換的 callback：測試環境沒有初始化 Firebase，
  /// `FirebaseCrashlytics.instance` 會直接拋 `[core/no-app]`；正式版若
  /// Firebase 初始化失敗，記錄錯誤本身會再拋二次例外，把單一功能失敗
  /// 放大成整條路徑中斷。
  static void Function(dynamic data, StackTrace stackTrace) crashReporter =
      (data, stackTrace) {
    try {
      FirebaseCrashlytics.instance.recordError(data, stackTrace);
    } catch (_) {
      // Firebase 尚未初始化或不可用，記錄錯誤本身不該再拋。
    }
  };

  static void eWithStack(dynamic data, StackTrace stackTrace) {
    //用於顯示已用try catch的處理error
    logger.e(data.toString(), stackTrace: stackTrace);
    crashReporter(data, stackTrace);
  }

  static void error(dynamic data, StackTrace stackTrace) {
    //用於顯示無try catch的error
    logger.e(data.toString(), stackTrace: stackTrace);
  }

  static void e(dynamic data) {
    //用於顯示已用try catch的處理error
    logger.e(data.toString());
  }

  static void d(dynamic data) {
    //用於debug的Log
    logger.d(data.toString());
  }
}
