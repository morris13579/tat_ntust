import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_themes.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// 模擬 `dynamic_color` 交出來的配色。
///
/// `CorePalette.toColorScheme()`（1.7.0 到 1.8.1）只填 surface 與
/// surfaceVariant，M3 的 surfaceContainer 那一整組都不設；Flutter 對沒設定的
/// 角色一律退回 surface。這裡刻意照樣只給這幾個欄位。
ColorScheme _deviceScheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7D5260),
    brightness: brightness,
  );
  return ColorScheme(
    brightness: brightness,
    primary: base.primary,
    onPrimary: base.onPrimary,
    secondary: base.secondary,
    onSecondary: base.onSecondary,
    error: base.error,
    onError: base.onError,
    surface: base.surface,
    onSurface: base.onSurface,
  );
}

void main() {
  group('動態配色缺 surfaceContainer 時', () {
    test('未修正的裝置配色，page 與 card 確實會撞在一起', () {
      // 這是 bug 的成因本身。這一條掛掉代表 Flutter 改了退回規則，
      // 那時 AppThemes 的補丁就可以拿掉了。
      final scheme = _deviceScheme(Brightness.light);
      expect(scheme.surfaceContainer, scheme.surface);
      expect(scheme.surfaceContainerLowest, scheme.surface);
    });

    for (final brightness in Brightness.values) {
      test('$brightness：主題補完後 page 與 card 不同色', () {
        final theme = brightness == Brightness.light
            ? AppThemes.lightTheme(_deviceScheme(brightness))
            : AppThemes.darkTheme(_deviceScheme(brightness));
        final tokens = theme.extension<TatTokens>()!;

        expect(tokens.card, isNot(tokens.page), reason: '卡片與底色同色，畫面上每張卡片都會消失');
        expect(theme.scaffoldBackgroundColor, tokens.page);
      });

      test('$brightness：surfaceContainer 各階彼此不同', () {
        final theme = brightness == Brightness.light
            ? AppThemes.lightTheme(_deviceScheme(brightness))
            : AppThemes.darkTheme(_deviceScheme(brightness));
        final s = theme.colorScheme;
        final ramp = {
          s.surfaceContainerLowest,
          s.surfaceContainerLow,
          s.surfaceContainer,
          s.surfaceContainerHigh,
          s.surfaceContainerHighest,
        };
        expect(ramp.length, 5, reason: '有階層塌回同一個顏色');
      });
    }

    test('裝置給的主色不會被重算', () {
      final scheme = _deviceScheme(Brightness.light);
      final theme = AppThemes.lightTheme(scheme);
      expect(theme.colorScheme.primary, scheme.primary);
      expect(theme.colorScheme.secondary, scheme.secondary);
      expect(theme.colorScheme.error, scheme.error);
    });
  });
}
