import 'package:flutter/material.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

/// 從畫面上緣落下來的提示，點得下去。
///
/// 和 [TatToast] 的分工：toast 確認「剛剛完成的動作」，2 秒、不吃點擊、沒有去處；
/// 這一個是「剛剛發生了一件事，你可能想去看」——所以它停久一點、可以點、也可以
/// 往上滑掉。系統推播長這樣，使用者不必學新東西。
///
/// **底層是 toastification，和 toast 不同。** toast 那一顆要的是「新的直接蓋掉
/// 舊的、不吃點擊、位置貼著導覽列」，那幾件事自己管一個 overlay 反而單純；橫幅
/// 要的是計時、可拖走、可點、進出場動畫，那正好是 toastification 現成的東西。
class InAppBanner {
  InAppBanner._();

  static const Duration visibleFor = Duration(seconds: 5);

  /// 同一時間只留一個。新信一次來三封時，後來的把前一個換掉而不是疊成一疊。
  static ToastificationItem? _current;

  static void show({
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? onTap,
  }) {
    final context = Get.context;
    if (context == null) return;
    dismiss();
    _current = toastification.showCustom(
      context: context,
      alignment: Alignment.topCenter,
      autoCloseDuration: visibleFor,
      animationDuration: const Duration(milliseconds: 320),
      animationBuilder: (context, animation, alignment, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            // 從上緣外面落下來，和系統推播同一個方向。
            position:
                Tween<Offset>(begin: const Offset(0, -0.35), end: Offset.zero)
                    .animate(curved),
            child: child,
          ),
        );
      },
      callbacks: const ToastificationCallbacks(onDismissed: _release),
      builder: (context, item) => _Banner(
        icon: icon,
        title: title,
        message: message,
        onTap: onTap == null
            ? null
            : () {
                dismiss();
                onTap();
              },
      ),
    );
  }

  static void dismiss() {
    final item = _current;
    _current = null;
    if (item != null) toastification.dismiss(item);
  }

  static void _release(ToastificationItem item) {
    if (_current?.id == item.id) _current = null;
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      // toastification 的 overlay 已經讓開安全區，這裡只補左右與一點呼吸。
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(TatTokens.radiusCard),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TatTokens.radiusCard),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyLarge?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
