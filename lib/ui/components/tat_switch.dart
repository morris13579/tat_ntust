import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 全 App 共用的開關。**不分平台**：`Switch.adaptive` 會在 iOS 畫成膠囊、
/// Android 畫成 M3 的膠囊加大圓點，同一份設定頁在兩台手機上長得不一樣。
///
/// 形狀跟著這份設計的其他元件走——軌道 10 的圓角、拇指 7，跟篩選 chip（8）與
/// 分段控制（6）同一族。**刻意不是膠囊**：擺在一排 chip 旁邊才不會像外來的元件。
///
/// 關閉時軌道描一圈細邊，否則淺色軌道放在同樣淺的卡片上會整顆消失——這是這份
/// 設計裡少數需要描邊的地方，因為它要撐出一個「可以按」的形狀。
class TatSwitch extends StatefulWidget {
  const TatSwitch({super.key, required this.value, this.onChanged});

  final bool value;

  /// null 代表停用。
  final ValueChanged<bool>? onChanged;

  static const double _trackWidth = 52;
  static const double _trackHeight = 32;
  static const double _thumbSize = 24;
  static const double _margin = 4;

  @override
  State<TatSwitch> createState() => _TatSwitchState();
}

class _TatSwitchState extends State<TatSwitch> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final enabled = widget.onChanged != null;
    final on = widget.value;

    final track = !enabled
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : on
            ? scheme.primary
            : scheme.surfaceContainerHighest;
    final thumb = !enabled
        ? scheme.outlineVariant
        : on
            ? scheme.onPrimary
            : scheme.onSurfaceVariant;

    return Focus(
      canRequestFocus: enabled,
      onFocusChange: (value) => setState(() => _focused = value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => widget.onChanged!(!on) : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: Semantics(
          toggled: on,
          enabled: enabled,
          child: AnimatedContainer(
            // 位移與底色同時走，150ms standard easing。
            duration: const Duration(milliseconds: 150),
            curve: Easing.standard,
            width: TatSwitch._trackWidth,
            height: TatSwitch._trackHeight,
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(10),
              border: !on && enabled
                  ? Border.all(color: scheme.outlineVariant)
                  : null,
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              curve: Easing.standard,
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: TatSwitch._margin),
                child: Container(
                  width: TatSwitch._thumbSize,
                  height: TatSwitch._thumbSize,
                  decoration: BoxDecoration(
                    color: thumb,
                    borderRadius: BorderRadius.circular(7),
                    // 按下時拇指外圈一層淡色，回饋不靠整顆變色。
                    boxShadow: _pressed
                        ? [
                            BoxShadow(
                              color: (on ? scheme.onPrimary : scheme.primary)
                                  .withValues(alpha: 0.28),
                              spreadRadius: 3,
                            )
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
