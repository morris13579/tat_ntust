import 'package:flutter/material.dart';

/// 把可為 null 的顏色轉成 SvgPicture 的 `colorFilter`。
///
/// null 代表「不上色」，而 [ColorFilter.mode] 不收 null，`Get.iconColor` 又正是
/// `Color?`（GetX 直接轉發 `theme.iconTheme.color`）。[BlendMode.srcIn] 是
/// flutter_svg 上色用的預設混合模式。
ColorFilter? svgTint(Color? color) =>
    color == null ? null : ColorFilter.mode(color, BlendMode.srcIn);
