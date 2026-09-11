import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

/// Toast 只確認「剛剛完成的動作」，所以沒有 error。
///
/// 錯誤需要一個重試入口，膠囊給不了：那些情況走提示條或對話框。
enum TatToastKind { success, info }

/// 底部膠囊提示。高 48、帶圖示、2 秒、沒有按鈕。
class TatToast {
  TatToast._();

  /// 同一時間只留一個浮層，後來的把前一個換掉。
  static OverlayEntry? _current;

  static void show(String message, {TatToastKind kind = TatToastKind.success}) {
    final overlay = Get.key.currentState?.overlay;
    if (overlay == null) return;
    _removeCurrent();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastView(
        message: message,
        kind: kind,
        onDismissed: () {
          if (identical(_current, entry)) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  static void _removeCurrent() {
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.kind,
    required this.onDismissed,
  });

  final String message;
  final TatToastKind kind;
  final VoidCallback onDismissed;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 120),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
    _timer = Timer(const Duration(seconds: 2), () => unawaited(_dismiss()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final icon = switch (widget.kind) {
      TatToastKind.success => LucideIcons.circleCheck,
      TatToastKind.info => LucideIcons.info,
    };
    return Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.paddingOf(context).bottom + 24,
      // 沒有按鈕，所以不吃點擊：底下的內容照樣能操作。
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, 8 * (1 - _controller.value)),
              child: child,
            ),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: scheme.inverseSurface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20, color: scheme.onInverseSurface),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium
                                ?.copyWith(color: scheme.onInverseSurface),
                          ),
                        ),
                      ),
                    ],
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
