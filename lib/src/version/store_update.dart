import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:upgrader/upgrader.dart';

/// 問商店有沒有新版：Android 走 Play 的 in-app update，iOS 查 App Store。
class StoreUpdate {
  StoreUpdate._();

  /// 有新版就交給商店（Play 自己的下載提示 / 開 App Store 頁面）並回 true；
  /// 沒有新版、或這份不是從商店裝的（debug、側載、沒有 Play 服務）回 false。
  static Future<bool> offer() async {
    if (Platform.isAndroid) {
      return _offerOnPlay();
    }
    if (Platform.isIOS) {
      return _offerOnAppStore();
    }
    return false;
  }

  /// Play 自己跳提示、在背景下載；上次下載完還沒裝的，這次啟動直接裝。
  static Future<bool> _offerOnPlay() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.installStatus == InstallStatus.downloaded) {
        await InAppUpdate.completeFlexibleUpdate();
        return true;
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }
      await InAppUpdate.startFlexibleUpdate();
      return true;
    } on PlatformException catch (e) {
      Log.d("play update: ${e.code} ${e.message}");
      return false;
    }
  }

  static Future<bool> _offerOnAppStore() async {
    final upgrader = Upgrader(debugLogging: kDebugMode);
    await upgrader.initialize();
    if (!upgrader.isUpdateAvailable()) {
      return false;
    }
    await upgrader.sendUserToAppStore();
    return true;
  }
}
