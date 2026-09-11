import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton(
      {super.key,
      required this.onPressed,
      required this.child,
      this.padding,
      this.width,
      this.backgroundColor,
      this.borderRadius,
      this.isLoading = false});

  /// null 代表停用。送出中只鎖這一顆，不再蓋一層全螢幕進度框。
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsets? padding;
  final double? width;
  final Color? backgroundColor;
  final BorderRadiusGeometry? borderRadius;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final effectiveChild = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : child;

    if (GetPlatform.isIOS) {
      return CupertinoButton(
        onPressed: effectiveOnPressed,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        child: Container(
            alignment: Alignment.center,
            width: width,
            padding: padding,
            decoration: BoxDecoration(
                color: backgroundColor, borderRadius: borderRadius),
            child: effectiveChild),
      );
    }
    return TextButton(
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.zero,
          ),
          minimumSize: Size(width ?? 0, 0),
          padding: padding,
        ),
        onPressed: effectiveOnPressed,
        child: effectiveChild);
  }
}
