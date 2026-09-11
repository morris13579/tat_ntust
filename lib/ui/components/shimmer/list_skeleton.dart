import 'package:flutter/material.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:shimmer/shimmer.dart';

/// 可指定列數的清單骨架。
///
/// 骨架的列數要接近真實資料的筆數，載入完成時版面才不會整個跳掉；不知道筆數
/// 時給一個小的值就好。
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    required this.rows,
    this.hasLeadingCircle = true,
    this.rowHeight = 56,
  });

  final int rows;
  final bool hasLeadingCircle;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final base = scheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: Color.lerp(base, scheme.surface, 0.6)!,
        period: const Duration(milliseconds: 2000),
        child: Column(
          children: [
            for (var i = 0; i < rows; i++)
              SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    if (hasLeadingCircle) ...[
                      Container(
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(color: base, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Bar(color: base, height: 14),
                          const SizedBox(height: 8),
                          _Bar(color: base, height: 12, width: 140),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.height, this.width});

  final Color color;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
