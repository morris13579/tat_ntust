import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/config/app_config.dart';
import 'package:path_provider/path_provider.dart';

/// Android 桌面小工具的更新。
///
/// 「寫檔 + 打 MethodChannel」集中在這裡，才能在沒有原生端的環境下測試，
/// 也才能在 iOS 上被明確地跳過。
class CourseWidgetService {
  const CourseWidgetService();

  static CourseWidgetService instance = const CourseWidgetService();

  static const _fileName = 'course_widget.png';

  /// 把課表截圖交給桌面小工具。回傳原生端是否確實更新成功。
  ///
  /// **原生端回 false 是有意義的**：`CourseWidgetProvider` 找不到小工具實例
  /// （使用者沒有把它加到主畫面）時就會回 false。呼叫端據此顯示不同的提示。
  Future<bool> publish(Uint8List png) async {
    final path = (await getApplicationSupportDirectory()).path;
    await File('$path/$_fileName').writeAsBytes(png);
    const platform = MethodChannel(AppConfig.methodChannelWidgetName);
    final result = await platform.invokeMethod<bool>('update_weight');
    Log.d("course widget updated: $result");
    return result ?? false;
  }
}
