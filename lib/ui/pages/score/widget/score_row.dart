import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_typography.dart';
import 'package:flutter_app/src/model/score/score_json.dart';
import 'package:flutter_app/src/util/score_utils.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:sprintf/sprintf.dart';

/// 成績清單的一列：課名、課號／學分／向度，分數靠右。
///
/// 整列可點，導頁由呼叫端注入，這一層不認得 route（見 docs/ARCHITECTURE.md
/// 「UI 慣例」）。原本只有分數可點而且點了跳 toast 唸同一個值；備註取代
/// 分數時唸出來的還是一個裸的「-」。
class ScoreRow extends StatelessWidget {
  const ScoreRow({
    super.key,
    required this.score,
    this.onTap,
    this.index = 0,
    this.length = 1,
  });

  final ScoreItemJson score;
  final VoidCallback? onTap;

  /// 用來決定這一列在群組裡的圓角。
  final int index;
  final int length;

  /// 學校把及格與否寫成中文字串，英文語系照搬會夾一段中文。
  static const _passLiterals = {'通過', 'Pass'};

  /// 分數欄要顯示的字。沒有等第時退回備註（抵免、停修…），兩者皆無就是還沒
  /// 評分——設計稿要的是字，不是一個看不出意思的「-」。
  static String scoreLabel(ScoreItemJson score) {
    final grade = score.score.trim();
    final text = (grade.isEmpty || grade == '-') ? score.remark.trim() : grade;
    if (text.isEmpty) return R.current.assignNotGraded;
    if (_passLiterals.contains(text)) return R.current.scorePassed;
    return text;
  }

  static String _subtitle(ScoreItemJson score) => [
        score.courseId,
        sprintf(R.current.creditCount, [ScoreUtils.parseCredit(score.credit)]),
        if (score.generalDimension.isNotEmpty)
          '${R.current.general_dimension} ${score.generalDimension}',
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tokens = context.tokens;
    final failed = score.isFailScore;
    final borderRadius = UIUtils.getBorderRadius(index, length);
    final label = scoreLabel(score);
    final subtitle = _subtitle(score);

    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: Semantics(
        // 不及格靠底色、chip 與紅字三種方式表達；讀螢幕的人只剩這一句。
        label: [
          score.name,
          subtitle,
          label,
          if (failed) R.current.scoreFailed,
        ].join('，'),
        excludeSemantics: true,
        child: Container(
          decoration: BoxDecoration(
            color: failed ? tokens.scoreFailContainer : context.tokens.card,
            borderRadius: borderRadius,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      score.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall
                          ?.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        if (failed) ...[
                          const SizedBox(width: 8),
                          _failChip(context),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  label,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.tabular(
                    context.text.titleMedium ?? const TextStyle(),
                  ).copyWith(
                    color: failed ? tokens.scoreFail : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// chip 的底色與前景刻意跟整列反過來：列底已經是 scoreFailContainer，
  /// 同色的 chip 等於不存在。
  Widget _failChip(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: tokens.scoreFail,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        R.current.scoreFailed,
        style: context.text.labelMedium
            ?.copyWith(color: tokens.scoreFailContainer),
      ),
    );
  }
}
