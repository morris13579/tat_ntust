import 'package:flutter/cupertino.dart';

class OverRepaintBoundary extends StatefulWidget {
  final Widget child;

  const OverRepaintBoundary({required Key key, required this.child}) : super(key: key);

  @override
  OverRepaintBoundaryState createState() => OverRepaintBoundaryState();
}

class OverRepaintBoundaryState extends State<OverRepaintBoundary> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
