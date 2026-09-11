import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

/// 主分頁用的 appbar：沒有返回鍵。
///
/// 底色、字色與 elevation 一律交給 `AppBarTheme`——原本這裡寫死
/// `Colors.transparent`，在動態取色下等於把整條 bar 的層級關掉。
/// `systemOverlayStyle` 也不再自己算：AppBar 會從實際的底色推狀態列圖示的
/// 明暗，而那個底色現在才是對的。
AppBar mainAppbar(
    {String title = "",
    String? subtitle,
    List<Widget>? action,
    bool isShowBack = false,
    PreferredSizeWidget? bottom}) {
  return AppBar(
    actions: action,
    // 有返回鍵時用跟 baseAppbar 同一顆：交給 AppBar 自己畫的話會是 Material
    // 預設的箭頭，跟其他頁面的 chevron 明顯不一樣。
    leading: isShowBack ? _backButton() : const SizedBox(width: 0),
    leadingWidth: !isShowBack ? 0 : null,
    bottom: bottom,
    // 有副標時整條 bar 要長高，否則兩行會被壓在 56 裡。
    toolbarHeight: subtitle == null ? null : 68,
    title: _title(title, subtitle),
  );
}

/// 標題（沿用 AppBarTheme 的字級，和其他頁一致）與可選的副標。
Widget _title(String title, String? subtitle) {
  if (subtitle == null) return Text(title);
  return Builder(
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTypography.tabular(
            context.text.bodySmall ?? const TextStyle(),
          ).copyWith(color: context.scheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

/// App 內唯一的一顆返回鍵。
///
/// 它出現在每一個子頁面上，沒有 tooltip 時螢幕閱讀器只會唸「按鈕」。用 Builder
/// 取得 AppBar 底下的 context：這兩個 appbar 都只是回傳 AppBar 的函式，沒有
/// 自己的 BuildContext。backButtonTooltip 由 GlobalMaterialLocalizations 提供。
Widget _backButton({VoidCallback? onBack}) => Builder(
      builder: (context) => IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        splashColor: Colors.transparent,
        splashRadius: 18,
        icon: const Icon(LucideIcons.chevronLeft, size: 18),
        // 有未送出內容或寫入正在跑的頁面會傳 onBack，把這顆鈕接到
        // `Navigator.maybePop`；`Get.back()` 是直接 pop，會跳過 PopScope。
        onPressed: onBack ?? Get.back,
      ),
    );

AppBar baseAppbar(
    {String title = "",
    List<Widget>? action,
    PreferredSizeWidget? bottom,
    VoidCallback? onBack}) {
  return AppBar(
    leading: _backButton(onBack: onBack),
    actions: action,
    bottom: bottom,
    title: Text(title),
  );
}
