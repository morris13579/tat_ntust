import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  late SharedPreferences _box;
  static ThemeService? _instance;
  int currentTheme = 0;
  final _key = 'isThemeMode';

  ThemeService._();

  static ThemeService get instance {
    _instance ??= ThemeService._();
    return _instance!;
  }

  ThemeMode get theme => ThemeMode.values[currentTheme];

  Future<void> init() async {
    _box = await SharedPreferences.getInstance();
    currentTheme = _box.getInt(_key) ?? 0;
  }

  void changeThemeMode(ThemeMode mode) {
    _box.setInt(_key, ThemeMode.values.indexOf(mode));
    Get.changeThemeMode(mode);
    Future.delayed(const Duration(milliseconds: 250), () {
      Get.forceAppUpdate();
    });
  }
}