import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

class TextShimmer extends StatelessWidget {
  const TextShimmer(
      {super.key, this.height = 18, this.width = 80, this.borderRadius = 4});

  final double height;
  final double width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        // 原本寫死白色，在亮色主題下等於整條看不見。
        color: context.scheme.surfaceContainerHighest,
      ),
    );
  }
}
