import 'package:flutter/material.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_app/src/util/moodle_quiz_text.dart';
import 'package:flutter_app/src/util/moodle_quiz_utils.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/status_pill.dart';

export 'package:flutter_app/src/util/moodle_quiz_text.dart'
    show
        quizAttemptStateText,
        quizDurationText,
        quizGradeMethodText,
        quizWindowHintText;

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
    return StatusPill(
      tone: QuizAttemptsText.exhausted(quiz, used)
          ? StatusPillTone.overdue
          : StatusPillTone.pending,
      stale: stale,
      label: QuizAttemptsText.label(quiz, used),
    );
  }
}
