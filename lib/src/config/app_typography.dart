import 'package:flutter/material.dart';

/// 調過的 TextTheme。
///
/// 設計稿量到的字級比 M3 預設緊一階（內文 15/1.7、段標題 17/600、對話框標題
/// 20/600/1.4、標籤 12/500），所以只覆寫這幾個角色，其餘留給 M3。
///
/// 一定要從 `ThemeData(...)` 的建構子傳進去：`GoogleFonts.notoSansTcTextTheme`
/// 只換字型，字級／字重／顏色都原樣保留，所以覆寫放在建構子裡換完字仍在。
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(TextTheme base) => base.copyWith(
        titleLarge: base.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        titleSmall: base.titleSmall?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, height: 1.7),
        bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
        bodySmall: base.bodySmall?.copyWith(fontSize: 12, height: 1.5),
        labelLarge: base.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: base.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );

  /// 成績、學分這種要上下對齊的數字欄。沒有任何 M3 角色帶等寬數字。
  static TextStyle tabular(TextStyle base) =>
      base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
