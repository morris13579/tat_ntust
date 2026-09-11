import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter/rendering.dart';

class WidgetSizeRenderObject extends RenderProxyBox {
  final Function(Size) onSizeChange;
  Size? currentSize;

  WidgetSizeRenderObject(this.onSizeChange);

  @override
  void performLayout() {
    super.performLayout();

    try {
      Size? newSize = child?.size;

      if (newSize != null && currentSize != newSize) {
        currentSize = newSize;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onSizeChange(newSize);
        });
      }
    } catch (e) {
      Log.e(e.toString());
    }
  }
}

class WidgetSizeOffsetWrapper extends SingleChildRenderObjectWidget {
  final Function(Size size) onSizeChange;

  const WidgetSizeOffsetWrapper({
    super.key,
    required this.onSizeChange,
    required Widget super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return WidgetSizeRenderObject(onSizeChange);
  }
}
