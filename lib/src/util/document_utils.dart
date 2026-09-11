import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_config.dart';
import 'package:flutter_app/src/file/file_store.dart';
import 'package:flutter_app/src/util/my_toast.dart';

class DocumentUtils {
  static const platform = MethodChannel(AppConfig.methodChannelSaveName);

  static Future<String?>? _getPath() =>
      platform.invokeMethod<String>("get_path");

  static Future<bool?>? _choiceFolder() =>
      platform.invokeMethod("choice_folder");

  /// 讓使用者選一個下載資料夾。
  ///
  /// 一律走原生的 SAF channel（`club.ntust.tat.save`），不需要依 sdkInt 分支：
  /// `ACTION_OPEN_DOCUMENT_TREE` 從 API 21 就存在，本專案 minSdkVersion 是 24。
  ///
  /// **不要為了選資料夾把 `file_picker` 加回來。** 它自帶的 consumer proguard
  /// 規則 `-keep class org.apache.tika.** { *; }` 在 R8 下一個人就釘住 5,055
  /// 個項目（比整個 Flutter embedding 還多），而 consumer 規則沒辦法從 App 端
  /// 取消，只能移除相依。
  static Future<dynamic> choiceFolder() async {
    if (Platform.isAndroid) {
      // 用 `picked != true` 而不是 `!`：使用者按返回時原生端回 false，
      // channel 也可能回 null（例如 Activity 被回收後重建）。
      final picked = await _choiceFolder();
      if (picked != true) return null;
      final directory = await _getPath();
      Log.d(directory);
      if (directory == "/" || directory == null) {
        MyToast.show(R.current.selectDirectoryFail);
        return null;
      } else {
        try {
          await Directory("$directory/TATFileAccessTest").create();
          await Directory("$directory/TATFileAccessTest").delete();
          await FileStore.setFilePath(directory);
          return directory;
        } catch (e) {
          MyToast.show(R.current.selectDirectoryFail);
          return null;
        }
      }
    }
    return null;
  }
}
