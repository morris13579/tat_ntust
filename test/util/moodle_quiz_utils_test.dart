import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/util/moodle_quiz_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// [MoodleQuizUtils] 的規格：開放時間、時限、次數、排序與成績格式。
/// 全是純函式，`now` 由測試給定，不碰時鐘也不碰 R.current。
void main() {
  final now = DateTime(2025, 9, 6, 12, 0);
  int unix(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  MoodleQuizAttempt attempt({
    int id = 1,
    int number = 1,
    String state = 'finished',
    int preview = 0,
  }) =>
      MoodleQuizAttempt(
        id: id,
        attempt: number,
        state: state,
        preview: preview,
      );

  group('windowHint', () {
    test('兩個時間都是 0 → 完全沒有時間限制', () {
      final hint = MoodleQuizUtils.windowHint(0, 0, now);

      expect(hint.kind, QuizWindowKind.always);
      expect(hint.hint, QuizHintKind.always);
      expect(hint.count, 0);
    });

    test('還沒開放：天 / 小時 / 一小時內', () {
      final days = MoodleQuizUtils.windowHint(
          unix(now.add(const Duration(days: 3, hours: 2))), 0, now);
      expect(days.kind, QuizWindowKind.beforeOpen);
      expect(days.hint, QuizHintKind.opensInDays);
      expect(days.count, 3);

      final hours = MoodleQuizUtils.windowHint(
          unix(now.add(const Duration(hours: 5))), 0, now);
      expect(hours.hint, QuizHintKind.opensInHours);
      expect(hours.count, 5);

      final soon = MoodleQuizUtils.windowHint(
          unix(now.add(const Duration(minutes: 40))), 0, now);
      expect(soon.hint, QuizHintKind.opensSoon);
      expect(soon.count, 0);
    });

    test('now 剛好等於 timeopen 算已開放，不是 beforeOpen', () {
      // 與 MoodleAssignUtils.isOverdue 的 >= 同一個邊界約定。
      final hint = MoodleQuizUtils.windowHint(unix(now), 0, now);

      expect(hint.kind, QuizWindowKind.open);
      expect(hint.hint, QuizHintKind.openNoClose);
    });

    test('開放中且有關閉時間：天 / 小時 / 一小時內', () {
      final open = unix(now.subtract(const Duration(days: 1)));

      final days = MoodleQuizUtils.windowHint(
          open, unix(now.add(const Duration(days: 2, hours: 3))), now);
      expect(days.kind, QuizWindowKind.open);
      expect(days.hint, QuizHintKind.closesInDays);
      expect(days.count, 2);

      final hours = MoodleQuizUtils.windowHint(
          open, unix(now.add(const Duration(hours: 7))), now);
      expect(hours.hint, QuizHintKind.closesInHours);
      expect(hours.count, 7);

      final soon = MoodleQuizUtils.windowHint(
          open, unix(now.add(const Duration(minutes: 10))), now);
      expect(soon.hint, QuizHintKind.closesSoon);
      expect(soon.count, 0);
    });

    test('now 剛好等於 timeclose 算已關閉', () {
      final hint = MoodleQuizUtils.windowHint(0, unix(now), now);

      expect(hint.kind, QuizWindowKind.closed);
      expect(hint.hint, QuizHintKind.closedJustNow);
    });

    test('已關閉：天 / 小時', () {
      final days = MoodleQuizUtils.windowHint(
          0, unix(now.subtract(const Duration(days: 2, hours: 1))), now);
      expect(days.kind, QuizWindowKind.closed);
      expect(days.hint, QuizHintKind.closedDays);
      expect(days.count, 2);

      final hours = MoodleQuizUtils.windowHint(
          0, unix(now.subtract(const Duration(hours: 3))), now);
      expect(hours.hint, QuizHintKind.closedHours);
      expect(hours.count, 3);
    });

    test('已開放但沒有關閉時間 → open / openNoClose', () {
      final hint = MoodleQuizUtils.windowHint(
          unix(now.subtract(const Duration(days: 10))), 0, now);

      expect(hint.kind, QuizWindowKind.open);
      expect(hint.hint, QuizHintKind.openNoClose);
      expect(hint.count, 0);
    });

    test('只有關閉時間而且還沒到 → open，不是 beforeOpen', () {
      final hint = MoodleQuizUtils.windowHint(
          0, unix(now.add(const Duration(days: 4))), now);

      expect(hint.kind, QuizWindowKind.open);
      expect(hint.hint, QuizHintKind.closesInDays);
      expect(hint.count, 4);
    });
  });

  group('hoursMinutes', () {
    test('0 與負數都是零', () {
      expect(MoodleQuizUtils.hoursMinutes(0), (hours: 0, minutes: 0));
      expect(MoodleQuizUtils.hoursMinutes(-60), (hours: 0, minutes: 0));
    });

    test('整點與半點', () {
      expect(MoodleQuizUtils.hoursMinutes(1800), (hours: 0, minutes: 30));
      expect(MoodleQuizUtils.hoursMinutes(3600), (hours: 1, minutes: 0));
      expect(MoodleQuizUtils.hoursMinutes(5400), (hours: 1, minutes: 30));
    });

    test('不足一分鐘無條件進位，不會寫成 0 分鐘', () {
      expect(MoodleQuizUtils.hoursMinutes(30), (hours: 0, minutes: 1));
      expect(MoodleQuizUtils.hoursMinutes(7259), (hours: 2, minutes: 1));
    });
  });

  group('attemptsUsed', () {
    test('finished 與 abandoned 算，inprogress 與 overdue 不算', () {
      // 判準抄 mod/quiz/view.php：quiz_get_user_attempts(..., 'finished')
      // 的 'finished' 是 state IN (FINISHED, ABANDONED)。
      final used = MoodleQuizUtils.attemptsUsed([
        attempt(id: 1, number: 1, state: 'finished'),
        attempt(id: 2, number: 2, state: 'abandoned'),
        attempt(id: 3, number: 3, state: 'inprogress'),
        attempt(id: 4, number: 4, state: 'overdue'),
      ]);

      expect(used, 2);
    });

    test('preview 永遠不算，空清單是 0', () {
      expect(
        MoodleQuizUtils.attemptsUsed([
          attempt(state: 'finished', preview: 1),
          attempt(id: 2, number: 2, state: 'finished'),
        ]),
        1,
      );
      expect(MoodleQuizUtils.attemptsUsed([]), 0);
    });
  });

  group('gradeMethodOf', () {
    test('四個常數各自對映，其餘是 unknown', () {
      expect(MoodleQuizUtils.gradeMethodOf(1), QuizGradeMethod.highest);
      expect(MoodleQuizUtils.gradeMethodOf(2), QuizGradeMethod.average);
      expect(MoodleQuizUtils.gradeMethodOf(3), QuizGradeMethod.first);
      expect(MoodleQuizUtils.gradeMethodOf(4), QuizGradeMethod.last);
      expect(MoodleQuizUtils.gradeMethodOf(0), QuizGradeMethod.unknown);
      expect(MoodleQuizUtils.gradeMethodOf(99), QuizGradeMethod.unknown);
    });
  });

  group('attemptStateOf', () {
    test('4.5 的四個字面值', () {
      expect(MoodleQuizUtils.attemptStateOf('inprogress'),
          QuizAttemptState.inProgress);
      expect(
          MoodleQuizUtils.attemptStateOf('overdue'), QuizAttemptState.overdue);
      expect(MoodleQuizUtils.attemptStateOf('finished'),
          QuizAttemptState.finished);
      expect(MoodleQuizUtils.attemptStateOf('abandoned'),
          QuizAttemptState.abandoned);
    });

    test('Moodle 5.0 才有的兩個也接得住', () {
      // 站台升級到 5.0 之後 get_user_quiz_attempts 會回這兩個，沒接住的話
      // 整排作答紀錄會變成「未知狀態」。
      expect(MoodleQuizUtils.attemptStateOf('notstarted'),
          QuizAttemptState.notStarted);
      expect(MoodleQuizUtils.attemptStateOf('submitted'),
          QuizAttemptState.submitted);
    });

    test('沒見過的字串是 unknown', () {
      expect(MoodleQuizUtils.attemptStateOf(''), QuizAttemptState.unknown);
      expect(
          MoodleQuizUtils.attemptStateOf('garbage'), QuizAttemptState.unknown);
    });
  });

  group('sortForList', () {
    test('最新的在前，不改動輸入', () {
      final input = [
        attempt(id: 1, number: 1),
        attempt(id: 2, number: 2),
        attempt(id: 3, number: 3),
      ];

      final sorted = MoodleQuizUtils.sortForList(input);

      expect(sorted.map((a) => a.attempt), [3, 2, 1]);
      expect(input.map((a) => a.attempt), [1, 2, 3], reason: '不可以就地排序');
    });

    test('同一個 attempt 編號維持輸入順序（List.sort 不穩定）', () {
      final sorted = MoodleQuizUtils.sortForList([
        attempt(id: 10, number: 1),
        attempt(id: 11, number: 1),
        attempt(id: 12, number: 2),
      ]);

      expect(sorted.map((a) => a.id), [12, 10, 11]);
    });

    test('空清單', () {
      expect(MoodleQuizUtils.sortForList([]), isEmpty);
    });
  });

  group('formatGrade', () {
    test('null 是空字串', () {
      expect(MoodleQuizUtils.formatGrade(null, 2), '');
    });

    test('照 decimalpoints 補零與四捨五入', () {
      expect(MoodleQuizUtils.formatGrade(8, 2), '8.00');
      expect(MoodleQuizUtils.formatGrade(8.456, 2), '8.46');
      expect(MoodleQuizUtils.formatGrade(8.456, 0), '8');
    });

    test('站台亂送 decimalpoints 也不拋（夾在 0..7）', () {
      expect(MoodleQuizUtils.formatGrade(8, -1), '8');
      expect(MoodleQuizUtils.formatGrade(8, 99), '8.0000000');
    });
  });

  group('findById', () {
    final items = [
      MoodleQuiz(id: 5101, name: 'a'),
      MoodleQuiz(id: 5102, name: 'b'),
    ];

    test('找得到、找不到、空清單', () {
      expect(MoodleQuizUtils.findById(items, 5102)!.name, 'b');
      expect(MoodleQuizUtils.findById(items, 9999), isNull);
      expect(MoodleQuizUtils.findById([], 5101), isNull);
    });
  });
}
