import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/util/moodle_quiz_utils.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';

/// [QuizWindowHint] 對映成畫面文字。
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

/// 測驗頁上的時間。
String quizFormatUnix(int unix) => DateFormat.yMd()
    .add_jm()
    .format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));

/// 「已用 2 / 3 次」那顆籤。
class QuizAttemptsText {
  QuizAttemptsText._();

  static String label(MoodleQuiz quiz, int used) => quiz.isUnlimitedAttempts
      ? R.current.quizAttemptsUnlimited
      : sprintf(R.current.quizAttemptsUsedOf, [used, quiz.attempts]);

  /// 次數用完了：那顆籤換警示色。
  static bool exhausted(MoodleQuiz quiz, int used) =>
      !quiz.isUnlimitedAttempts && used >= quiz.attempts;
}
