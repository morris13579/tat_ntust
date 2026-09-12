import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

/// 畫面底部那顆膠囊。
///
/// **只有這一個。** 「取得課表中…」的進度提示和信箱的 toast 曾經是兩個各自手寫
/// 的膠囊：圓角、內距、離導覽列多遠、有沒有動畫全都不一樣，而它們會在同一個位置
/// 先後出現。外觀收在這裡，兩邊都用它。
///
/// 尺寸沿用這個 App 一直以來的那一顆：高 48、左右內距 20、整顆圓、
/// `inverseSurface` 底配 `onInverseSurface` 字。
class TatBottomPill extends StatelessWidget {
  const TatBottomPill({
    super.key,
    required this.leading,
    required this.message,
    this.trailing,
  });

  /// 左邊那一個：進度是轉圈，提示是圖示。
  final Widget leading;

  final String message;

  /// 右邊那一顆按鈕，例如「收回」。沒有就不佔位置。
  final Widget? trailing;

  /// 膠囊的高度。兩行字的訊息會自己長高，這是下限。
  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minHeight: height),
        padding: EdgeInsets.fromLTRB(20, 10, trailing == null ? 20 : 8, 10),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(height / 2),
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
            leading,
            const SizedBox(width: 8),
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium
                      ?.copyWith(color: scheme.onInverseSurface, height: 1.35),
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 膠囊離畫面底部多遠（不含安全區）。
///
/// **導覽列只有主畫面那一層有。** 信件內頁、寫信頁都是推上來的頁面，沒有導覽
/// 列；`Get.context` 一律是 root navigator 的 context，光看它分不出這兩種頁面，
/// 所以要問 navigator 自己推不推得回去。
double tatBottomPillInset() {
  final hasNavigationBar = !(Get.key.currentState?.canPop() ?? false);
  // 64 是 NavigationBarThemeData.height（見 app_styles.dart），再加一點呼吸。
  return (hasNavigationBar ? 64.0 : 0.0) + 24;
}
