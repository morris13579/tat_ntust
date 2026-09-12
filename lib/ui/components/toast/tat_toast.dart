import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/tat_progress.dart';
import 'package:flutter_app/ui/components/toast/tat_bottom_pill.dart';
import 'package:flutter_app/ui/other/lucide_icons.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

/// 畫面底部的提示。**全 App 只有這一條路**會把膠囊放上畫面。
///
/// **底層是自己插一個 `OverlayEntry`，不是 toastification。** 曾經搬過去，換來
/// 一連串的坑：它把每一則塞進寫死 400 寬的框（膠囊被撐開、內容貼左）、只把
/// `Interval(0.3, 1)` 那一段交給 `animationBuilder`（180ms 實際只剩 126ms，看起來
/// 像硬跳出來）、自己又加一次安全區與鍵盤高度（位置算兩遍），而且插入排在
/// post-frame callback、移除卻是當下就做——「收掉舊的再放新的」會讓
/// `AnimatedList` 索引對不上，之後一顆膠囊都不剩。自己管一個 overlay 這幾件事
/// 都不存在，而且動畫與位置說了算。
///
/// **不要用 `Get.snackbar`。** 除了難看，它還會壞掉功能：GetX 的 `Get.back()`
/// 第一件事是「有 snackbar 開著就只關 snackbar 然後 return」，所以「先 toast 再
/// `Get.back()`」那一段程式看起來合理、實際上頁面關不掉。
///
/// 兩種用法，差別在活多久，以及佔不佔那個「唯一的提示名額」：
/// - [show] / [action]：講一句話就收掉。同時只留一則，新的直接蓋掉舊的。
/// - [progress]：掛著直到那件事做完（「取得課表中…」），回一個 handle 讓呼叫端
///   自己收。它代表一件還沒做完的事，不該被一句「已複製」擠掉，所以不佔名額；
///   兩者同時在的時候往上堆。
enum TatToastKind { success, info, error }

/// 掛著的那一顆。呼叫端拿它來收。
class TatToastHandle {
  TatToastHandle._(this._pill);

  final _Pill? _pill;

  /// 收掉。多呼叫幾次是安全的。
  void dismiss() => _pill?.dismiss();
}

class TatToast {
  TatToast._();

  static const Duration _duration = Duration(seconds: 2);

  /// 錯誤停久一點：那句話通常比「已複製」長，而且使用者需要讀完它。
  static const Duration _errorDuration = Duration(seconds: 4);

  /// 目前畫面上的膠囊，由下往上。
  static final List<_Pill> _pills = [];

  /// 講一句話，時間到自己收。新的一句直接蓋掉上一句。
  static void show(String message, {TatToastKind kind = TatToastKind.success}) {
    final context = Get.context;
    if (context == null) return;
    final scheme = context.scheme;
    final tokens = context.tokens;
    final (icon, color) = switch (kind) {
      TatToastKind.success => (LucideIcons.circleCheck, tokens.success),
      TatToastKind.info => (LucideIcons.info, scheme.onInverseSurface),
      TatToastKind.error => (LucideIcons.triangleAlert, scheme.error),
    };
    _replaceToast(_Pill(
      leadingBuilder: (context) => Icon(icon, size: 20, color: color),
      message: message,
      autoClose: kind == TatToastKind.error ? _errorDuration : _duration,
    ));
  }

  /// 帶一顆按鈕的提示，例如「寄送中 — 收回」。
  ///
  /// **這是「來得及收回」唯一可靠的出口。** 寄件匣那一段只畫在信件清單的最上面，
  /// 使用者捲到一半才去寫信、或寄完就切去別的分頁時根本看不到它，那五秒的窗口
  /// 等於不存在。提示跟著使用者走，就沒有這個問題。
  ///
  /// [duration] 通常就是那個窗口本身：按鈕消失的時間和它真的失效的時間一致，
  /// 不要留一顆按下去沒用的鈕。
  static void action(
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    required Duration duration,
  }) {
    final context = Get.context;
    if (context == null) return;
    late final _Pill pill;
    pill = _Pill(
      leadingBuilder: (context) => Icon(LucideIcons.send,
          size: 20, color: context.scheme.onInverseSurface),
      message: message,
      autoClose: duration,
      actionLabel: actionLabel,
      onAction: () {
        pill.dismiss();
        onAction();
      },
    );
    _replaceToast(pill);
  }

  /// 掛一顆轉圈的，直到呼叫端自己收。**不佔提示那個名額。**
  static TatToastHandle progress(String message) {
    if (Get.key.currentState?.overlay == null) {
      return TatToastHandle._(null);
    }
    final pill = _Pill(
      leadingBuilder: (context) =>
          TatProgress(size: 16, color: context.scheme.onInverseSurface),
      message: message,
      autoClose: null,
    );
    _insert(pill);
    return TatToastHandle._(pill);
  }

  /// 測試用：把畫面上的膠囊全部收掉。
  @visibleForTesting
  static void resetForTest() {
    for (final pill in [..._pills]) {
      pill.removeNow();
    }
    _pills.clear();
  }

  /// 目前有幾顆膠囊。測試用。
  @visibleForTesting
  static int get pillCount => _pills.length;

  static void _replaceToast(_Pill pill) {
    // 舊的那一則**立刻**拿掉，不跑退場動畫：新舊兩則的形狀與位置一樣，讓舊的
    // 淡出反而會和新的交疊，看起來像閃了一下。
    for (final existing in [..._pills]) {
      if (!existing.sticky) existing.removeNow();
    }
    _insert(pill);
  }

  static void _insert(_Pill pill) {
    final overlay = Get.key.currentState?.overlay;
    if (overlay == null) return;
    _pills.add(pill);
    pill._attach(overlay, _onPillGone);
    _reflow();
  }

  static void _onPillGone(_Pill pill) {
    if (!_pills.remove(pill)) return;
    _reflow();
  }

  /// 重算每一顆離底部多遠。同時有進度與提示時往上堆，不要疊在一起。
  static void _reflow() {
    for (var i = 0; i < _pills.length; i++) {
      _pills[i].setIndex(i);
    }
  }
}

/// 一顆膠囊的生命週期：插進 overlay、倒數、淡出、拿掉。
class _Pill {
  _Pill({
    required this.leadingBuilder,
    required this.message,
    required this.autoClose,
    this.actionLabel,
    this.onAction,
  });

  final WidgetBuilder leadingBuilder;
  final String message;

  /// null 代表不自動收——那是進度提示。
  final Duration? autoClose;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// 進度提示不佔「同時只留一則」的名額。
  bool get sticky => autoClose == null;

  final ValueNotifier<int> _index = ValueNotifier<int>(0);
  OverlayEntry? _entry;
  void Function(_Pill)? _onGone;
  bool _gone = false;

  void _attach(OverlayState overlay, void Function(_Pill) onGone) {
    _onGone = onGone;
    final entry = OverlayEntry(
      builder: (context) => _PillView(
        pill: this,
        onDismissed: removeNow,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  void setIndex(int value) => _index.value = value;

  ValueListenable<int> get index => _index;

  /// 淡出之後再拿掉。使用者按了動作鈕或計時器到了走這一條。
  void dismiss() => _requestReverse?.call();

  VoidCallback? _requestReverse;

  /// 立刻拿掉，不跑動畫。
  void removeNow() {
    if (_gone) return;
    _gone = true;
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
    _index.dispose();
    _onGone?.call(this);
  }
}

/// 膠囊本體。動畫與位置都在這裡。
class _PillView extends StatefulWidget {
  const _PillView({required this.pill, required this.onDismissed});

  final _Pill pill;
  final VoidCallback onDismissed;

  @override
  State<_PillView> createState() => _PillViewState();
}

class _PillViewState extends State<_PillView>
    with SingleTickerProviderStateMixin {
  /// 和這個 App 一直以來的那一顆同一組：進場 160、退場 120。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 120),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.pill._requestReverse = _dismiss;
    unawaited(_controller.forward());
    final autoClose = widget.pill.autoClose;
    if (autoClose != null) _timer = Timer(autoClose, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final pill = TatBottomPill(
      leading: widget.pill.leadingBuilder(context),
      message: widget.pill.message,
      trailing: widget.pill.actionLabel == null
          ? null
          : TextButton(
              onPressed: widget.pill.onAction,
              style: TextButton.styleFrom(
                foregroundColor: context.scheme.inversePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(widget.pill.actionLabel!),
            ),
    );
    return ValueListenableBuilder<int>(
      valueListenable: widget.pill.index,
      builder: (context, index, child) => Positioned(
        left: 24,
        right: 24,
        // 鍵盤升起時跟著上來，不然它會被蓋掉。
        bottom: MediaQuery.paddingOf(context).bottom +
            MediaQuery.viewInsetsOf(context).bottom +
            tatBottomPillInset() +
            index * (TatBottomPill.height + 8),
        child: child!,
      ),
      child: FadeTransition(
        opacity: _controller,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 8 * (1 - _controller.value)),
            child: child,
          ),
          // 沒有按鈕的那些不吃點擊：底下的內容照樣能操作。
          child: Center(
            child: widget.pill.actionLabel == null
                ? IgnorePointer(child: pill)
                : pill,
          ),
        ),
      ),
    );
  }
}
