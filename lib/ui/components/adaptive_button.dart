import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({super.key, required this.onPressed, required this.child, this.padding, this.width, this.backgroundColor, this.borderRadius});

  final Function() onPressed;
  final Widget child;
  final EdgeInsets? padding;
  final double? width;
  final Color? backgroundColor;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (GetPlatform.isIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        minSize: 0,
        padding: EdgeInsets.zero,
        child: Container(
          alignment: Alignment.center,
          width: width,
          padding: padding,
          decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius
          ),
          child: child
        ),
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
      onPressed: onPressed,
      child: child
    );
  }
}
