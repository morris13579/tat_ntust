import 'package:flutter/material.dart';

class PathBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget child;

  const PathBar({
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child;
  }

  @override
  Size get preferredSize => const Size.fromHeight(40.0);
}
