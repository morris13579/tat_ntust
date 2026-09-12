import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/enum/classroom_view.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 清單／一整天的切換器。
///
/// **放在大樓那一列的右邊，不放 app bar。** 它切的是「怎麼看這一棟」，跟
/// 大樓、時段是同一組決定；app bar 的動作屬於整個頁面。
///
/// 選中的底色是一塊**會滑動的**指示器，不是兩顆各自變色的按鈕：兩段之間
/// 有位移關係，直接換色看起來像閃一下，滑過去才看得出「從左邊換到右邊」。
class ClassroomViewToggle extends StatelessWidget {
  const ClassroomViewToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ClassroomView value;
  final ValueChanged<ClassroomView> onChanged;

  /// 一段的寬度。兩段寫死同寬，指示器才滑得準；標籤只有兩個短詞，不會被裁。
  static const double _segmentWidth = 64;
  static const double _segmentHeight = 30;
  static const double _padding = 3;
  static const Duration _duration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(TatTokens.radiusButton),
      ),
      // 尺寸寫死才控制得住：Stack 裡沒有定位的 Align 會撐到可用寬度的極限，
      // 整顆切換器會被拉寬、第二段被擠掉。
      child: SizedBox(
        width: _segmentWidth * 2,
        height: _segmentHeight,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: _duration,
              curve: Curves.easeOutCubic,
              left: value == ClassroomView.list ? 0 : _segmentWidth,
              top: 0,
              width: _segmentWidth,
              height: _segmentHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius:
                      BorderRadius.circular(TatTokens.radiusButton - _padding),
                ),
              ),
            ),
            Row(
              children: [
                _segment(
                    context, ClassroomView.list, R.current.classroomViewList),
                _segment(
                    context, ClassroomView.day, R.current.classroomViewDay),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, ClassroomView view, String label) {
    final selected = view == value;
    final scheme = context.scheme;
    return SizedBox(
      width: _segmentWidth,
      height: _segmentHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(TatTokens.radiusButton - _padding),
          onTap: selected ? null : () => onChanged(view),
          child: Center(
            // 文字顏色跟著指示器一起過渡，不然它會在指示器滑到一半時就跳色。
            child: AnimatedDefaultTextStyle(
              duration: _duration,
              curve: Curves.easeOutCubic,
              style: context.text.labelLarge?.copyWith(
                    height: 1.4,
                    color:
                        selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ) ??
                  const TextStyle(),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
