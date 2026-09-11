import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/service/error_dialog_parameter.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

export 'package:flutter_app/src/service/error_dialog_parameter.dart'
    show TatDialogKind;

/// App 內唯一的對話框骨架。
///
/// 種類之間只差標題前那顆 8px 圓點的顏色：插圖會把標題擠掉，而抓資料失敗一天
/// 會看好幾次，不需要每次都表演一遍。
class TatDialog extends StatelessWidget {
  const TatDialog({
    super.key,
    required this.title,
    required this.body,
    this.kind = TatDialogKind.error,
    this.destructive = false,
    this.primary,
    this.secondary,
    this.content,
  });

  final String title;
  final String? body;
  final TatDialogKind kind;

  /// 主鈕換成 error 底。
  final bool destructive;

  /// 右邊那顆。只有一顆按鈕時它會撐滿整列。
  final TatDialogAction? primary;

  /// 左邊那顆，慣例是取消。
  final TatDialogAction? secondary;

  /// 輸入型對話框把欄位放這裡，跟著 [body] 一起捲。
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    final hasActions = primary != null || secondary != null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TatTokens.dialogMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(TatTokens.dialogPadding,
                  TatTokens.dialogPadding, TatTokens.dialogPadding, 0),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _dotColor(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: context.text.titleLarge),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _DialogBody(
                body: body,
                content: content,
                hasActions: hasActions,
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
              ),
            ),
            if (hasActions)
              Padding(
                padding: const EdgeInsets.all(TatTokens.dialogPadding),
                child: Row(
                  children: [
                    if (secondary != null)
                      Expanded(
                          child:
                              _button(context, secondary!, isPrimary: false)),
                    if (secondary != null && primary != null)
                      const SizedBox(width: 8),
                    if (primary != null)
                      Expanded(
                          child: _button(context, primary!, isPrimary: true)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _dotColor(BuildContext context) => switch (kind) {
        TatDialogKind.error => context.scheme.error,
        TatDialogKind.warning => context.tokens.warning,
        TatDialogKind.info => context.tokens.info,
        TatDialogKind.success => context.tokens.success,
      };

  Widget _button(BuildContext context, TatDialogAction action,
      {required bool isPrimary}) {
    final scheme = context.scheme;
    final foreground = isPrimary
        ? (destructive ? scheme.onError : scheme.onPrimary)
        : scheme.onSurface;
    final background = isPrimary
        ? (destructive ? scheme.error : scheme.primary)
        : scheme.surfaceContainerHighest;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
      ),
      // 載入中只鎖這一顆，不再蓋一層全螢幕進度框。
      onPressed: action.onPressed == null || action.isLoading
          ? null
          : () => unawaited(Future<void>.sync(action.onPressed!)),
      child: action.isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: foreground.withValues(alpha: 0.7)),
            )
          : Text(action.label),
    );
  }
}

/// 對話框上的一顆按鈕。
class TatDialogAction {
  const TatDialogAction({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final FutureOr<void> Function()? onPressed;
  final bool isLoading;
}

/// 開一個對話框並等它的回傳值。
///
/// 泛型是必要的：有兩個呼叫端需要三值結果（null 代表取消，false 是另一個
/// 有意義的答案），`bool` 包不下。點遮罩預設不關——對話框在等一個決定，
/// 誤觸關掉會讓呼叫端收到「使用者拒絕」。
Future<T?> showTatDialog<T>({
  required Widget dialog,
  bool barrierDismissible = false,
}) {
  final navigator = Get.key.currentState;
  if (navigator == null) return Future<T?>.value();
  final context = navigator.context;
  return navigator.push<T>(_TatDialogRoute<T>(
    child: dialog,
    dismissible: barrierDismissible,
    shade: Theme.of(context).dialogTheme.barrierColor ?? Colors.black54,
    dismissLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  ));
}

/// 進場 160ms 淡入 + Y 8→0、退場 120ms 純淡出。
///
/// 自己寫一條 route 而不是用 `Get.dialog`：進退場長度不同，只有
/// [TransitionRoute.reverseTransitionDuration] 能表達。
class _TatDialogRoute<T> extends PopupRoute<T> {
  _TatDialogRoute({
    required this.child,
    required this.dismissible,
    required this.shade,
    required this.dismissLabel,
  });

  final Widget child;
  final bool dismissible;
  final Color shade;
  final String dismissLabel;

  @override
  Color? get barrierColor => shade;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => dismissLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      Semantics(scopesRoute: true, explicitChildNodes: true, child: child);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // reverseCurve 用 Threshold(0)：退場時位移直接停在 0，只剩淡出。
    final offset = Tween<double>(begin: 8, end: 0).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: const Threshold(0),
    ));
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: AnimatedBuilder(
        animation: offset,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, offset.value), child: child),
        child: child,
      ),
    );
  }
}

/// 內文與自訂內容。超過畫面 40% 就自己捲，並在按鈕上方補一條分隔線。
class _DialogBody extends StatefulWidget {
  const _DialogBody({
    required this.body,
    required this.content,
    required this.hasActions,
    required this.maxHeight,
  });

  final String? body;
  final Widget? content;
  final bool hasActions;
  final double maxHeight;

  @override
  State<_DialogBody> createState() => _DialogBodyState();
}

class _DialogBodyState extends State<_DialogBody> {
  final ScrollController _controller = ScrollController();
  bool _scrolls = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(_DialogBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 有沒有捲動空間要等排版完才知道，所以在下一幀量。
  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final scrolls = _controller.position.maxScrollExtent > 0;
      if (scrolls != _scrolls) setState(() => _scrolls = scrolls);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.body == null && widget.content == null) {
      return const SizedBox(height: TatTokens.dialogPadding);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: SingleChildScrollView(
              controller: _controller,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    TatTokens.dialogPadding,
                    8,
                    TatTokens.dialogPadding,
                    widget.hasActions ? 0 : TatTokens.dialogPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.body != null)
                      Text(widget.body!, style: context.text.bodyLarge),
                    if (widget.body != null && widget.content != null)
                      const SizedBox(height: 12),
                    if (widget.content != null) widget.content!,
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_scrolls && widget.hasActions) const Divider(),
      ],
    );
  }
}
