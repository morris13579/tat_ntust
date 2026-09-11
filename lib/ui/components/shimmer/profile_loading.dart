import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/shimmer/text_shimmer.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:shimmer/shimmer.dart';

/// 「更多」頁頂端那一列個人資料的骨架。
class ProfileLoading extends StatelessWidget {
  const ProfileLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final base = scheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: Color.lerp(base, scheme.surface, 0.6)!,
        period: const Duration(milliseconds: 2000),
        child: Row(
          children: [
            CircleAvatar(radius: 24, backgroundColor: base),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextShimmer(),
                SizedBox(height: 8),
                TextShimmer(width: 160),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
