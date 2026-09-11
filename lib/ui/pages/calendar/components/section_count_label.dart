import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 區塊標題右邊的件數。等寬數字，上下幾組的數字才對得齊。
class SectionCountLabel extends StatelessWidget {
  const SectionCountLabel(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      sprintf(R.current.itemCount, [count]),
      style: AppTypography.tabular(context.text.bodySmall!)
          .copyWith(color: context.scheme.onSurfaceVariant),
    );
  }
}
