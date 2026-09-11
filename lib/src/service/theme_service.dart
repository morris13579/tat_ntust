import 'dart:async';
import 'package:flutter_app/src/store/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeService {
  static ThemeService? _instance;
  int currentTheme = 0;

  ThemeService._();

  static ThemeService get instance {
    _instance ??= ThemeService._();
    return _instance!;
  }

  ThemeMode get theme => ThemeMode.values[currentTheme];

  Future<void> init() async {
    currentTheme = await SettingsStore.instance.themeModeIndex;
  }

  /// 切換主題並落盤。
  ///
  /// 先換畫面再寫入：使用者看到的是即時反應。寫入以 await 收尾，失敗往上拋
  /// 給呼叫端——吞掉的話使用者重開 App 會發現主題跳回去，而且沒有線索。
  ///
  /// 250 毫秒之後的 forceAppUpdate 維持 fire-and-forget，那是為了讓部分沒有
  /// 訂閱主題的頁面重繪，刻意不讓呼叫端等它。
  Future<void> changeThemeMode(ThemeMode mode) async {
    currentTheme = ThemeMode.values.indexOf(mode);
    Get.changeThemeMode(mode);
    unawaited(Future.delayed(const Duration(milliseconds: 250))
        .then((_) => Get.forceAppUpdate()));
    await SettingsStore.instance.setThemeModeIndex(currentTheme);
  }
}
