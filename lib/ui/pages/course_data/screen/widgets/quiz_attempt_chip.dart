import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/moodle_quiz_utils.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/status_pill.dart';
import 'package:sprintf/sprintf.dart';

/// [QuizWindowHint] 對映成畫面文字。住在 UI 層是因為要 R.current。
String quizWindowHintText(QuizWindowHint hint) => switch (hint.hint) {
      QuizHintKind.always => R.current.quizAlwaysOpen,
      QuizHintKind.opensInDays =>
        sprintf(R.current.quizOpensInDays, [hint.count]),
      QuizHintKind.opensInHours =>
        sprintf(R.current.quizOpensInHours, [hint.count]),
      QuizHintKind.opensSoon => R.current.quizOpensSoon,
      QuizHintKind.openNoClose => R.current.quizOpenNoClose,
      QuizHintKind.closesInDays =>
        sprintf(R.current.quizClosesInDays, [hint.count]),
      QuizHintKind.closesInHours =>
        sprintf(R.current.quizClosesInHours, [hint.count]),
      QuizHintKind.closesSoon => R.current.quizClosesSoon,
      QuizHintKind.closedDays =>
        sprintf(R.current.quizClosedDays, [hint.count]),
      QuizHintKind.closedHours =>
        sprintf(R.current.quizClosedHours, [hint.count]),
      QuizHintKind.closedJustNow => R.current.quizClosedJustNow,
    };

String quizGradeMethodText(QuizGradeMethod method) => switch (method) {
      QuizGradeMethod.highest => R.current.quizGradeMethodHighest,
      QuizGradeMethod.average => R.current.quizGradeMethodAverage,
      QuizGradeMethod.first => R.current.quizGradeMethodFirst,
      QuizGradeMethod.last => R.current.quizGradeMethodLast,
      QuizGradeMethod.unknown => R.current.quizGradeMethodUnknown,
    };

String quizAttemptStateText(QuizAttemptState state) => switch (state) {
      QuizAttemptState.notStarted => R.current.quizAttemptStateNotStarted,
      QuizAttemptState.inProgress => R.current.quizAttemptStateInProgress,
      QuizAttemptState.submitted => R.current.quizAttemptStateSubmitted,
      QuizAttemptState.overdue => R.current.quizAttemptStateOverdue,
      QuizAttemptState.finished => R.current.quizAttemptStateFinished,
      QuizAttemptState.abandoned => R.current.quizAttemptStateAbandoned,
      QuizAttemptState.unknown => R.current.quizAttemptStateUnknown,
    };

/// 秒數對映成「X 小時 Y 分鐘」。分鐘無條件進位，30 秒的時限不會寫成 0 分鐘。
String quizDurationText(int seconds) {
  final d = MoodleQuizUtils.hoursMinutes(seconds);
  final hours = sprintf(R.current.quizDurationHours, [d.hours]);
  final minutes = sprintf(R.current.quizDurationMinutes, [d.minutes]);
  if (d.hours > 0 && d.minutes > 0) return "$hours $minutes";
  return d.hours > 0 ? hours : minutes;
}

/// 一次作答的狀態籤；外觀走共用的 [StatusPill]，刻意不 import 任何頁面。
class QuizAttemptStateChip extends StatelessWidget {
  const QuizAttemptStateChip(this.state, {super.key});

  final QuizAttemptState state;

  @override
  Widget build(BuildContext context) {
    final tone = switch (state) {
      QuizAttemptState.finished => StatusPillTone.graded,
      QuizAttemptState.submitted => StatusPillTone.submitted,
      QuizAttemptState.inProgress => StatusPillTone.draft,
      QuizAttemptState.overdue => StatusPillTone.overdue,
      QuizAttemptState.abandoned ||
      QuizAttemptState.notStarted ||
      QuizAttemptState.unknown =>
        StatusPillTone.pending,
    };
    return StatusPill(
      tone: tone,
      label: quizAttemptStateText(state),
    );
  }
}

/// 「已用 2 / 3 次」那顆籤，放在「作答規則」的段標題右邊。
class QuizAttemptsChip extends StatelessWidget {
  const QuizAttemptsChip({
    super.key,
    required this.quiz,
    required this.used,
    this.stale = false,
  });

  final MoodleQuiz quiz;
  final int used;

  /// 資料來自快取（[Stale]）時多畫一個時鐘小圖示。
  final bool stale;

  /// null 還在抓畫轉圈；[Failed] 什麼都不畫（底下的區塊自己會畫 InlineErrorView）。
  static Widget fromResult(
      MoodleQuiz quiz, Result<List<MoodleQuizAttempt>>? result) {
    if (result == null) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final data = result.dataOrNull;
    if (data == null) return const SizedBox.shrink();
    return QuizAttemptsChip(
      quiz: quiz,
      used: MoodleQuizUtils.attemptsUsed(data),
      stale: result is Stale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final exhausted = !quiz.isUnlimitedAttempts && used >= quiz.attempts;
    return StatusPill(
      tone: exhausted ? StatusPillTone.overdue : StatusPillTone.pending,
      stale: stale,
      label: quiz.isUnlimitedAttempts
          ? R.current.quizAttemptsUnlimited
          : sprintf(R.current.quizAttemptsUsedOf, [used, quiz.attempts]),
    );
  }
}
