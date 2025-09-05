import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/course_config.dart';
import 'package:get/get.dart';

class UIUtils {
  UIUtils._();

  static Color getListColor(int index) {
    return ((index % 2 == 1)
            ? Get.theme.colorScheme.surface
            : Get.theme.colorScheme.surfaceVariant)
        .withAlpha(CourseConfig.courseTableWithAlpha);
  }

  static Color getOnColor(Color backgroundColor) {
    return ThemeData.estimateBrightnessForColor(backgroundColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  static List<Color> generateHarmoniousColors(int count) {
    final List<Color> colors = [];
    final HSLColor hslSeed = HSLColor.fromColor(Get.theme.colorScheme.primary);

    final double rotation = 360.0 / (count + 1);

    for (int i = 0; i < count; i++) {
      final double currentHue = (hslSeed.hue + i * rotation) % 360.0;

      final HSLColor derivedColor = HSLColor.fromAHSL(
        1.0,
        currentHue,
        0.4,
        0.9,
      );
      colors.add(derivedColor.toColor());
    }
    return colors;
  }
}
