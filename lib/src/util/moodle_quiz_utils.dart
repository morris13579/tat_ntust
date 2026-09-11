import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';

/// 開放時間的三態，另加「完全沒有時間限制」。
enum QuizWindowKind { always, beforeOpen, open, closed }

/// 開放時間的相對提示。字串對映在 UI 層（要 R.current）。
enum QuizHintKind {
  always,
  opensInDays,
  opensInHours,
  opensSoon,
  openNoClose,
  closesInDays,
  closesInHours,
  closesSoon,
  closedDays,
  closedHours,
  closedJustNow,
}

typedef QuizWindowHint = ({QuizWindowKind kind, QuizHintKind hint, int count});

enum QuizGradeMethod { highest, average, first, last, unknown }

enum QuizAttemptState {
  notStarted,
  inProgress,
  submitted,
  overdue,
  finished,
  abandoned,
  unknown,
}

/// 測驗的開放時間、次數與成績格式的純函式。不碰 R.current 也不碰時鐘，
/// `now` 一律由呼叫端傳進來。
class MoodleQuizUtils {
  MoodleQuizUtils._();

  /// `QUIZ_GRADEHIGHEST`…`QUIZ_ATTEMPTLAST`（mod/quiz/lib.php）。
  static const int gradeHighest = 1;
  static const int gradeAverage = 2;
  static const int attemptFirst = 3;
  static const int attemptLast = 4;

  static QuizGradeMethod gradeMethodOf(int value) => switch (value) {
        gradeHighest => QuizGradeMethod.highest,
        gradeAverage => QuizGradeMethod.average,
        attemptFirst => QuizGradeMethod.first,
        attemptLast => QuizGradeMethod.last,
        _ => QuizGradeMethod.unknown,
      };

  /// 前兩個只在 Moodle 5.0 的 `mod_quiz_get_user_quiz_attempts` 才出現，
  /// 先接住，站台升級時才不會整排變成「未知狀態」。
  static QuizAttemptState attemptStateOf(String raw) => switch (raw) {
        'notstarted' => QuizAttemptState.notStarted,
        'inprogress' => QuizAttemptState.inProgress,
        'submitted' => QuizAttemptState.submitted,
        'overdue' => QuizAttemptState.overdue,
        'finished' => QuizAttemptState.finished,
        'abandoned' => QuizAttemptState.abandoned,
        _ => QuizAttemptState.unknown,
      };

  /// 開放時間的提示。[timeopen] / [timeclose] 是 Unix 秒，0 = 沒有限制。
  ///
  /// `now` 剛好等於 `timeopen` 算已開放、等於 `timeclose` 算已關閉，與
  /// `MoodleAssignUtils.isOverdue` 的 `>=` 同一個約定。
  static QuizWindowHint windowHint(int timeopen, int timeclose, DateTime now) {
    final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

    if (timeopen > 0 && nowUnix < timeopen) {
      final diff =
          DateTime.fromMillisecondsSinceEpoch(timeopen * 1000).difference(now);
      if (diff.inDays >= 1) {
        return (
          kind: QuizWindowKind.beforeOpen,
          hint: QuizHintKind.opensInDays,
          count: diff.inDays
        );
      }
      if (diff.inHours >= 1) {
        return (
          kind: QuizWindowKind.beforeOpen,
          hint: QuizHintKind.opensInHours,
          count: diff.inHours
        );
      }
      return (
        kind: QuizWindowKind.beforeOpen,
        hint: QuizHintKind.opensSoon,
        count: 0
      );
    }

    if (timeclose > 0 && nowUnix >= timeclose) {
      final past =
          now.difference(DateTime.fromMillisecondsSinceEpoch(timeclose * 1000));
      if (past.inDays >= 1) {
        return (
          kind: QuizWindowKind.closed,
          hint: QuizHintKind.closedDays,
          count: past.inDays
        );
      }
      if (past.inHours >= 1) {
        return (
          kind: QuizWindowKind.closed,
          hint: QuizHintKind.closedHours,
          count: past.inHours
        );
      }
      return (
        kind: QuizWindowKind.closed,
        hint: QuizHintKind.closedJustNow,
        count: 0
      );
    }

    if (timeclose > 0) {
      final diff =
          DateTime.fromMillisecondsSinceEpoch(timeclose * 1000).difference(now);
      if (diff.inDays >= 1) {
        return (
          kind: QuizWindowKind.open,
          hint: QuizHintKind.closesInDays,
          count: diff.inDays
        );
      }
      if (diff.inHours >= 1) {
        return (
          kind: QuizWindowKind.open,
          hint: QuizHintKind.closesInHours,
          count: diff.inHours
        );
      }
      return (
        kind: QuizWindowKind.open,
        hint: QuizHintKind.closesSoon,
        count: 0
      );
    }

    if (timeopen > 0) {
      return (
        kind: QuizWindowKind.open,
        hint: QuizHintKind.openNoClose,
        count: 0
      );
    }

    return (kind: QuizWindowKind.always, hint: QuizHintKind.always, count: 0);
  }

  /// 秒數拆成小時與分鐘。分鐘無條件進位，30 秒的時限不會寫成「0 分鐘」。
  static ({int hours, int minutes}) hoursMinutes(int seconds) {
    if (seconds <= 0) return (hours: 0, minutes: 0);
    final hours = seconds ~/ 3600;
    final rest = seconds % 3600;
    return (hours: hours, minutes: (rest + 59) ~/ 60);
  }

  /// 已用掉的作答次數。判準抄自 `mod/quiz/view.php:80,99`：
  /// `quiz_get_user_attempts(..., 'finished', true)` 再 `count()`，而那裡的
  /// `'finished'` 是 `state IN (FINISHED, ABANDONED)`——作答中的那一次還沒
  /// 消耗掉次數。預覽永遠不算。
  static int attemptsUsed(List<MoodleQuizAttempt> attempts) {
    var used = 0;
    for (final a in attempts) {
      if (a.isPreview) continue;
      final state = attemptStateOf(a.state);
      if (state == QuizAttemptState.finished ||
          state == QuizAttemptState.abandoned) {
        used++;
      }
    }
    return used;
  }

  /// 最新的排在前面。伺服器排的是 `quiz, attempt ASC`（`quiz_get_user_attempts`
  /// 的 SQL）。同鍵拿原 index 當次鍵，因為 `List.sort` 不穩定。不改動輸入。
  static List<MoodleQuizAttempt> sortForList(List<MoodleQuizAttempt> items) {
    final indexed = [
      for (var i = 0; i < items.length; i++) (index: i, item: items[i]),
    ];
    indexed.sort((x, y) {
      final c = y.item.attempt.compareTo(x.item.attempt);
      if (c != 0) return c;
      return x.index.compareTo(y.index);
    });
    return [for (final e in indexed) e.item];
  }

  static MoodleQuiz? findById(List<MoodleQuiz> items, int id) {
    for (final q in items) {
      if (q.id == id) return q;
    }
    return null;
  }

  /// 照 `quiz_format_grade($quiz, $grade)` = `format_float($grade,
  /// $quiz->decimalpoints)`。[decimalpoints] 是 VALUE_OPTIONAL 的整數，站台
  /// 亂送時 `toStringAsFixed` 會拋，所以先夾住。
  static String formatGrade(num? grade, int decimalpoints) {
    if (grade == null) return "";
    return grade.toDouble().toStringAsFixed(decimalpoints.clamp(0, 7));
  }
}
