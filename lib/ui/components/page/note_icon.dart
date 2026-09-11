import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 說明句開頭那顆 icon，對齊到文字**第一行**的中線。
///
/// icon 的方框是邊長 [size] 的正方形，但一行文字的行框高是
/// `fontSize × height`（bodySmall 是 12 × 1.5 = 18）。在
/// [CrossAxisAlignment.start] 的 Row 裡直接放 Icon，貼齊的是行框頂端，icon
/// 看起來就浮在文字的光學中心上方。這裡把 icon 撐成第一行的高度再置中，換行
/// 之後仍然對著第一行，字級或行高改了也不必回來調偏移量。
class NoteIcon extends StatelessWidget {
  const NoteIcon(
    this.icon, {
    super.key,
    required this.style,
    this.size = 16,
    this.color,
  });

  final IconData icon;

  /// 旁邊那段文字的樣式，icon 對齊它第一行的中線。
  final TextStyle? style;

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // height 沒設時字體自己的行高無從得知，退回 icon 原本的大小，也就是修正前
    // 的行為——寧可不動，也不要拿猜出來的數字去推。
    final lineHeight = (style?.fontSize ?? 0) * (style?.height ?? 0);
    return SizedBox(
      height: math.max(lineHeight, size),
      child: Center(child: Icon(icon, size: size, color: color)),
    );
  }
}
