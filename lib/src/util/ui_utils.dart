import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/course_config.dart';
import 'package:get/get.dart';

class UIUtils {
  UIUtils._();

  static Color getListColor(int index) {
    return ((index % 2 == 1)
            ? Get.theme.colorScheme.surface
            : Get.theme.colorScheme.surfaceContainer)
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
    final bool isLight = Get.theme.brightness == Brightness.light;

    final double lightness = isLight ? 0.90 : 0.85;

    final double rotation = 360.0 / (count + 1);

    for (int i = 0; i < count; i++) {
      final double currentHue = (hslSeed.hue + i * rotation) % 360.0;

      final HSLColor derivedColor = HSLColor.fromAHSL(1.0, currentHue, 0.4, lightness);
      colors.add(derivedColor.toColor());
    }
    return colors;
  }

  static BorderRadius? getBorderRadius(int index, int length) {
    const baseRadius = 14.0;
    const subRadius = 4.0;
    BorderRadius? borderRadius;

    if (length == 1) {
      borderRadius = BorderRadius.circular(baseRadius);
    } else if (index == 0) {
      borderRadius = const BorderRadius.vertical(
          top: Radius.circular(baseRadius),
          bottom: Radius.circular(subRadius));
    } else if (index == length - 1) {
      borderRadius = const BorderRadius.vertical(
          top: Radius.circular(subRadius),
          bottom: Radius.circular(baseRadius));
    } else {
      borderRadius = BorderRadius.circular(subRadius);
    }

    return borderRadius;
  }
}
