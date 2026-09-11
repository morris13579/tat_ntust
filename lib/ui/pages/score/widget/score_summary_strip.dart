import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_tokens.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/ui/other/theme_context.dart';

/// 一個學期的成績摘要：GPA、學分、不及格門數三格。
///
/// 三個數字都是等寬數字，切學期時位數不會左右跳。
class ScoreSummaryStrip extends StatelessWidget {
  const ScoreSummaryStrip({
    super.key,
    required this.gpa,
    required this.credit,
    required this.failed,
  });

  /// null 代表這學期算不出 GPA（一門有效成績都沒有）。
  final String? gpa;
  final int credit;
  final int failed;

  /// 沒有值時放破折號而不是 0：0.00 會被讀成「這學期 GPA 是零」。
  static const _noValue = '—';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.card,
        borderRadius: BorderRadius.circular(TatTokens.radiusCard),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _cell(context, R.current.gpaLabel, gpa ?? _noValue)),
          _separator(context),
          Expanded(child: _cell(context, R.current.credit, '$credit')),
          _separator(context),
          Expanded(
            child: _cell(
              context,
              R.current.scoreFailed,
              '$failed',
              // 0 門不及格不值得標紅。
              highlight: failed > 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _separator(BuildContext context) => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: context.scheme.outlineVariant,
      );

  Widget _cell(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          style: AppTypography.tabular(
            context.text.headlineSmall ?? const TextStyle(),
          ).copyWith(
            fontWeight: FontWeight.w700,
            color:
                highlight ? context.tokens.scoreFail : context.scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
