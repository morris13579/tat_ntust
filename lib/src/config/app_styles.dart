import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';

/// 各元件主題。
///
/// 每一個 factory 都「收」已經建好的 ColorScheme，不自己去問全域主題——
/// 這些東西是在 ThemeData 還在建構的當下被呼叫的，那時候問到的一定是別套主題。
///
/// 設計稿沒有描邊卡片也沒有陰影：層級只用 bg / surface / raised 三階加 1px
/// 髮線，所以下面一律 elevation 0、surfaceTint 透明，靠遮罩與底色分離。
class AppStyles {
  AppStyles._();

  static IconThemeData iconTheme(ColorScheme s, TatTokens t) =>
      IconThemeData(color: s.onSurface, size: 20);

  static DialogThemeData dialogTheme(ColorScheme s, TatTokens t) =>
      DialogThemeData(
        backgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        barrierColor: s.scrim.withValues(alpha: TatTokens.scrimOpacity),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        actionsPadding: const EdgeInsets.all(TatTokens.dialogPadding),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(TatTokens.radiusDialog)),
        ),
      );

  static BottomSheetThemeData bottomSheetTheme(ColorScheme s, TatTokens t) =>
      BottomSheetThemeData(
        backgroundColor: t.card,
        modalBackgroundColor: t.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: s.scrim.withValues(alpha: TatTokens.scrimOpacity),
        showDragHandle: true,
        dragHandleColor: s.outlineVariant,
        dragHandleSize: const Size(36, 4),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(TatTokens.radiusSheet)),
        ),
      );

  /// 填色、無描邊。1.5px 的 error 圈是唯一會畫出來的邊，平時保留成透明的同寬
  /// 邊框，出錯時盒子才不會突然長高 3px。
  static InputDecorationTheme inputTheme(
      ColorScheme s, TatTokens tokens, TextTheme t) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(TatTokens.radiusField),
          borderSide: BorderSide(color: color, width: 1.5),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: s.surfaceContainerHighest,
      constraints: const BoxConstraints(minHeight: TatTokens.heightField),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      disabledBorder: border(Colors.transparent),
      focusedBorder: border(Colors.transparent),
      errorBorder: border(s.error),
      focusedErrorBorder: border(s.error),
      // 行高要壓回 1.2：內文的 1.6 會在單行輸入框裡把字頂到上緣，和左邊的
      // 圖示對不齊。
      hintStyle: t.bodyMedium?.copyWith(color: s.onSurfaceVariant, height: 1.2),
      labelStyle:
          t.bodyMedium?.copyWith(color: s.onSurfaceVariant, height: 1.2),
      errorStyle: t.bodySmall?.copyWith(color: s.error),
      helperStyle: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
      suffixIconColor: s.onSurfaceVariant,
      prefixIconColor: s.onSurfaceVariant,
    );
  }

  static FilledButtonThemeData filledButtonTheme(ColorScheme s, TatTokens t) =>
      FilledButtonThemeData(style: _buttonStyle(s.primary, s.onPrimary));

  static TextButtonThemeData textButtonTheme(ColorScheme s, TatTokens t) =>
      TextButtonThemeData(style: _buttonStyle(null, s.primary));

  static ButtonStyle _buttonStyle(Color? background, Color foreground) =>
      ButtonStyle(
        backgroundColor:
            background == null ? null : WidgetStatePropertyAll(background),
        foregroundColor: WidgetStatePropertyAll(foreground),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        minimumSize:
            const WidgetStatePropertyAll(Size(64, TatTokens.heightButton)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(TatTokens.radiusButton)),
          ),
        ),
      );

  static ListTileThemeData listTileTheme(ColorScheme s, TatTokens t) =>
      ListTileThemeData(
        iconColor: s.onSurfaceVariant,
        textColor: s.onSurface,
        minTileHeight: TatTokens.heightRow,
        minLeadingWidth: TatTokens.iconColumn,
        horizontalTitleGap: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      );

  static DividerThemeData dividerTheme(ColorScheme s, TatTokens t) =>
      DividerThemeData(
        color: s.outlineVariant,
        thickness: 1,
        space: 1,
      );

  /// 卡片不描邊、不打陰影，只靠底色比 surface 高一階。
  static CardThemeData cardTheme(ColorScheme s, TatTokens t) => CardThemeData(
        color: t.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(TatTokens.radiusCard)),
        ),
      );

  static NavigationBarThemeData navigationBarTheme(
          ColorScheme s, TatTokens t) =>
      NavigationBarThemeData(
        backgroundColor: t.page,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: s.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? s.onSecondaryContainer
                : s.onSurfaceVariant,
          ),
        ),
      );

  static AppBarTheme appBarTheme(ColorScheme s, TatTokens t) => AppBarTheme(
        backgroundColor: t.page,
        foregroundColor: s.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: s.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: s.onSurface, size: 22),
      );

  static SnackBarThemeData snackBarTheme(ColorScheme s, TatTokens t) =>
      SnackBarThemeData(
        backgroundColor: s.inverseSurface,
        actionTextColor: s.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(TatTokens.radiusCard)),
        ),
      );
}
