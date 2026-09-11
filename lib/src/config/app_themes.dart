import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_colors.dart';
import 'package:flutter_app/src/config/app_styles.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:google_fonts/google_fonts.dart';

/// 兩套主題共用的字體設定。
///
/// 用 google_fonts 在執行期抓 Noto Sans TC，不內建字體檔（省 APK 體積）。
/// 選 Noto Sans TC 是因為它是唯一字形完整、不會缺字的選項：M PLUS
/// Rounded 1c 風格較近但是日文字體，繁中獨有的字會掉回系統字體，
/// 同一行混兩種字型。
///
/// 抓不到字體時 google_fonts 會回退到系統字體，離線首啟照常可用，只是字型不同。
class AppThemes {
  /// 裝置給得出配色就整組直接用。先前是把它塞回 `fromSeed` 的 seedColor，
  /// 等於把 Android 12+ 完整的色調表壓成一個色相再重算一遍。
  static ThemeData lightTheme(ColorScheme? lightDynamic) => _build(
        lightDynamic == null
            ? ColorScheme.fromSeed(
                seedColor: AppColors.fallbackSeed,
                brightness: Brightness.light,
              )
            : _withSurfaceRamp(lightDynamic),
      );

  static ThemeData darkTheme(ColorScheme? darkDynamic) => _build(
        darkDynamic == null
            ? ColorScheme.fromSeed(
                seedColor: AppColors.fallbackSeed,
                brightness: Brightness.dark,
              )
            : _withSurfaceRamp(darkDynamic),
      );

  /// 補上動態配色缺的 surface 階層。
  ///
  /// `dynamic_color` 的 `CorePalette.toColorScheme()`（到 1.8.1 為止）只填
  /// `surface` 與 `surfaceVariant`，**M3 的 surfaceContainer 那一整組都沒設**。
  /// Flutter 對沒設定的角色一律退回 `surface`，於是 `TatTokens.page` 與
  /// `TatTokens.card` 會變成同一個顏色——Android 12+ 上每一張卡片都會消失，
  /// 整頁看起來只有一塊底色。
  ///
  /// 只補這幾階，primary／secondary／tertiary／error 仍然照裝置給的用，不重算。
  static ColorScheme _withSurfaceRamp(ColorScheme scheme) {
    final ramp = ColorScheme.fromSeed(
      seedColor: scheme.primary,
      brightness: scheme.brightness,
    );
    return scheme.copyWith(
      surfaceDim: ramp.surfaceDim,
      surfaceBright: ramp.surfaceBright,
      surfaceContainerLowest: ramp.surfaceContainerLowest,
      surfaceContainerLow: ramp.surfaceContainerLow,
      surfaceContainer: ramp.surfaceContainer,
      surfaceContainerHigh: ramp.surfaceContainerHigh,
      surfaceContainerHighest: ramp.surfaceContainerHighest,
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    final textTheme = AppTypography.textTheme(_baseTextTheme(scheme));
    final tokens = TatTokens.from(scheme);
    return _withFont(ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      extensions: [tokens],
      scaffoldBackgroundColor: tokens.page,
      iconTheme: AppStyles.iconTheme(scheme, tokens),
      dialogTheme: AppStyles.dialogTheme(scheme, tokens),
      bottomSheetTheme: AppStyles.bottomSheetTheme(scheme, tokens),
      inputDecorationTheme: AppStyles.inputTheme(scheme, tokens, textTheme),
      filledButtonTheme: AppStyles.filledButtonTheme(scheme, tokens),
      textButtonTheme: AppStyles.textButtonTheme(scheme, tokens),
      listTileTheme: AppStyles.listTileTheme(scheme, tokens),
      dividerTheme: AppStyles.dividerTheme(scheme, tokens),
      cardTheme: AppStyles.cardTheme(scheme, tokens),
      navigationBarTheme: AppStyles.navigationBarTheme(scheme, tokens),
      appBarTheme: AppStyles.appBarTheme(scheme, tokens),
      snackBarTheme: AppStyles.snackBarTheme(scheme, tokens),
    ));
  }

  /// ThemeData 自己算預設字體的那一段，先算出來給 AppTypography 當基底，
  /// 覆寫過的字級才不會被建構子再 merge 一次蓋回去。
  static TextTheme _baseTextTheme(ColorScheme scheme) {
    final typography = Typography.material2021(
      platform: defaultTargetPlatform,
      colorScheme: scheme,
    );
    return typography.englishLike.merge(
      scheme.brightness == Brightness.dark
          ? typography.white
          : typography.black,
    );
  }

  /// 套字體。只換字型，字級、字重與顏色都留著。
  ///
  /// primaryTextTheme 不再一起換：M3 底下沒人讀，換它只是讓 google_fonts
  /// 啟動時多做一倍的工。
  static ThemeData _withFont(ThemeData base) =>
      base.copyWith(textTheme: GoogleFonts.notoSansTcTextTheme(base.textTheme));
}
