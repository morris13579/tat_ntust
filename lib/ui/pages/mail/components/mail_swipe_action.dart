import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// 滑動選單裡的一顆動作。
///
/// **圓鈕在上、字在下，顏色只出現在圓裡面。** 先前是一整塊染色的圓角矩形把圖示
/// 與文字一起包進去，滑開之後那一排色塊和清單的卡片搶視覺；iOS 信件的做法是一
/// 顆實心圓鈕配底下一行灰字，份量集中而不吵。
///
/// **一定要回 `Expanded`。** `ActionPane` 把 children 交給 motion 的 Flex 去排，
/// 沒有 flex 的子項會拿到零寬度——整排按鈕就是一片空白。套件自己的
/// `CustomSlidableAction` 也是回 `Expanded`，這不是可選的包裝。
///
/// **圓鈕跟著手指長大。** 從 [_minScale] 補到 1，進度和信件卡的圓角同一個來源
/// （`SlidableController.ratio` 除以那一排的 `extentRatio`）。這是「厚實」真正
/// 的來源——套件把放開後的回彈寫死成 200ms 的 `Curves.ease`，公開 API 改不到，
/// 但拖的那一段是我們自己的。
class MailSwipeAction extends StatelessWidget {
  const MailSwipeAction({
    super.key,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.extentRatio,
  });

  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final IconData icon;
  final String label;

  /// 這一排露出多寬。拿來把 `ratio` 換算成 0..1 的進度。
  final double extentRatio;

  /// 圓鈕的直徑。44 是可點範圍的下限，再小就不好按。
  static const double diameter = 44;

  /// 剛拉開時的大小。不從 0 開始——那樣看起來像蹦出來，不是被拉出來。
  static const double _minScale = 0.62;

  @override
  Widget build(BuildContext context) {
    final controller = Slidable.of(context);
    final button = _button(context);
    return Expanded(
      child: controller == null
          ? button
          : AnimatedBuilder(
              animation: controller.animation,
              child: button,
              builder: (context, child) {
                final t = extentRatio <= 0
                    ? 1.0
                    : (controller.ratio.abs() / extentRatio).clamp(0.0, 1.0);
                return Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: _minScale + (1 - _minScale) * t,
                    child: child,
                  ),
                );
              },
            ),
    );
  }

  Widget _button(BuildContext context) => Semantics(
        button: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: diameter,
              height: diameter,
              child: Material(
                color: background,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    // 按了就把這一列收起來：動作已經發生，選單留著沒有意義。
                    Slidable.of(context)?.close();
                    onPressed();
                  },
                  child: Icon(icon, size: 20, color: foreground),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
}
