import 'package:flutter/material.dart';

/// 課表配色不走這裡，用 `UIUtils.generateHarmoniousColors`。
class AppColors {
  AppColors._();

  /// 只在 dynamic_color 交不出配色時當種子（iOS 一律如此，Android 12 以下也是）。
  static const Color fallbackSeed = Color(0xFF1565C0);
}
