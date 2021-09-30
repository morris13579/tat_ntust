import 'package:flutter/material.dart';

class PathBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget child;

  PathBar({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }

  @override
  Size get preferredSize => Size.fromHeight(40.0);
}
