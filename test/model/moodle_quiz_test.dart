import 'dart:convert';

import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_best_grade.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/moodle_quiz_fixtures.dart';

/// 三支 quiz 回應的解析契約（原始 fromJson；`name` 的 HTML 實體還原在
/// connector，見 moodle_webapi_quiz_test）。
///
/// fixture 帶齊所有 TAT 不建模的欄位，因為 `attempt_structure()` 與
/// `get_quizzes_by_courses_returns` 的每個欄位都是 VALUE_OPTIONAL：
/// 少送不能拋，多送也不能拋。
void main() {
  /// 模型宣告的欄位，也就是會被寫進 `cache_moodle_quiz` 的全部 key。
  const quizKeys = {
    'id',
    'coursemodule',
    'name',
    'intro',
    'timeopen',
    'timeclose',
    'timelimit',
    'attempts',
    'grademethod',
    'decimalpoints',
    'grade',
  };

  const attemptKeys = {
    'id',
    'attempt',
    'state',
    'preview',
    'timestart',
    'timefinish',
  };

  group('MoodleQuiz', () {
    late MoodleModQuizGetQuizzesByCourses parsed;

    setUpAll(() {
      parsed = MoodleModQuizGetQuizzesByCourses.fromJson(
          loadMoodleQuizFixture('get_quizzes'));
    });

    test('兩份測驗，未建模的欄位不會拋', () {
      expect(parsed.quizzes, hasLength(2));
    });

    test('第一份：每個保留的欄位都對得上', () {
      final q = rawFixtureQuiz(0);

      expect(q.id, 5101);
      expect(q.coursemodule, 94001);
      // 伺服器 format_string 過的字串；模型不還原，connector 才做。
      expect(q.name, '期中考 &amp; 小考');
      expect(q.intro, contains('<b>1-5</b>'));
      expect(q.timeopen, 1757548800);
      expect(q.timeclose, 1757556000);
      expect(q.timelimit, 3600);
      expect(q.attempts, 3);
      expect(q.grademethod, 1);
      expect(q.decimalpoints, 2);
      expect(q.grade, 20);
      expect(q.hasTimeLimit, isTrue);
      expect(q.hasOpenWindow, isTrue);
      expect(q.isUnlimitedAttempts, isFalse);
    });

    test('第二份：沒有時間限制、不限次數', () {
      final q = rawFixtureQuiz(1);

      expect(q.timeopen, 0);
      expect(q.timeclose, 0);
      expect(q.hasOpenWindow, isFalse);
      expect(q.hasTimeLimit, isFalse);
      expect(q.isUnlimitedAttempts, isTrue);
      expect(q.decimalpoints, 1);
    });

    test('PARAM_FLOAT 的 grade 整數與小數都收得下（num 不是 double）', () {
      // 宣告成 double 時整數的 10 會直接 TypeError。
      expect(MoodleQuiz.fromJson({'id': 1, 'grade': 10}).grade, 10);
      expect(MoodleQuiz.fromJson({'id': 1, 'grade': 10.5}).grade, 10.5);
    });

    test('每個 VALUE_OPTIONAL 欄位缺席都退回預設值，只有 id 也不拋', () {
      final q = MoodleQuiz.fromJson({'id': 5199});

      expect(q.coursemodule, 0);
      expect(q.name, '');
      expect(q.intro, isNull);
      expect(q.timeopen, 0);
      expect(q.timeclose, 0);
      expect(q.timelimit, 0);
      expect(q.attempts, 0);
      expect(q.grademethod, 0);
      // 站台沒送就照 Moodle 自己的 quiz | decimalpoints 預設值。
      expect(q.decimalpoints, 2);
      expect(q.grade, isNull);
    });

    test('quizzes 缺席時是空清單', () {
      expect(MoodleModQuizGetQuizzesByCourses.fromJson({}).quizzes, isEmpty);
    });

    test('toJson 只寫出宣告過的 key，round-trip 不掉欄位', () {
      final q = parsed.quizzes[0];
      final encoded = jsonDecode(jsonEncode(q)) as Map<String, dynamic>;

      expect(encoded.keys.toSet(), quizKeys);
      expect(encoded, isNot(contains('preferredbehaviour')));
      expect(encoded, isNot(contains('sumgrades')));

      final again = MoodleQuiz.fromJson(encoded);
      expect(again.id, q.id);
      expect(again.coursemodule, q.coursemodule);
      expect(again.grade, q.grade);
      expect(again.decimalpoints, q.decimalpoints);
    });
  });

  group('MoodleQuizAttempt', () {
    late MoodleModQuizGetUserAttempts parsed;

    setUpAll(() {
      parsed = MoodleModQuizGetUserAttempts.fromJson(
          loadMoodleQuizFixture('attempts_mixed'));
    });

    test('三筆，伺服器的 attempt ASC 順序原樣保留', () {
      expect(parsed.attempts.map((a) => a.attempt), [1, 2, 3]);
      expect(parsed.attempts.map((a) => a.state),
          ['finished', 'abandoned', 'inprogress']);
    });

    test('null 的 sumgrades / timecheckstate 只是被忽略，不是致命的', () {
      // 兩個欄位都沒建模，但伺服器對學生一定會送 null 進來。
      final a = parsed.attempts[2];

      expect(a.id, 71003);
      expect(a.timestart, 1757553000);
      expect(a.timefinish, 0);
      expect(a.hasFinished, isFalse);
      expect(a.isPreview, isFalse);
    });

    test('preview 是整數不是 bool', () {
      final withPreview = MoodleModQuizGetUserAttempts.fromJson(
          loadMoodleQuizFixture('attempts_with_preview'));

      expect(withPreview.attempts.first.preview, 1);
      expect(withPreview.attempts.first.isPreview, isTrue);
    });

    test('全部欄位缺席也不拋', () {
      final a = MoodleQuizAttempt.fromJson({});

      expect(a.id, 0);
      expect(a.attempt, 0);
      expect(a.state, '');
      expect(a.preview, 0);
      expect(a.timestart, 0);
      expect(a.timefinish, 0);
    });

    test('toJson 只寫出宣告過的 key', () {
      final encoded =
          jsonDecode(jsonEncode(parsed.attempts.first)) as Map<String, dynamic>;

      expect(encoded.keys.toSet(), attemptKeys);
      expect(encoded, isNot(contains('sumgrades')));
      expect(encoded, isNot(contains('gradeitemmarks')));
      expect(MoodleQuizAttempt.fromJson(encoded).state, 'finished');
    });
  });

  group('MoodleQuizBestGrade', () {
    test('有成績也有及格分數', () {
      final g =
          MoodleQuizBestGrade.fromJson(loadMoodleQuizFixture('best_grade'));

      expect(g.hasgrade, isTrue);
      expect(g.grade, 12.5);
      expect(g.gradetopass, 10);
      expect(g.hasGradeToPass, isTrue);
    });

    test('沒有成績時 grade 缺席，不會被當成 0', () {
      final g = MoodleQuizBestGrade.fromJson(
          loadMoodleQuizFixture('best_grade_no_grade'));

      expect(g.hasgrade, isFalse);
      expect(g.grade, isNull);
    });

    test('沒設及格分數時 gradetopass 保持 null（不是 0）', () {
      // 伺服器只在 gradepass 非零時才送這個 key，補成 0 會多畫一列「0 分及格」。
      final g = MoodleQuizBestGrade.fromJson(
          loadMoodleQuizFixture('best_grade_no_pass'));

      expect(g.grade, 18);
      expect(g.gradetopass, isNull);
      expect(g.hasGradeToPass, isFalse);
    });

    test('toJson round-trip', () {
      final encoded = jsonDecode(jsonEncode(fixtureBestGrade('best_grade')))
          as Map<String, dynamic>;

      expect(encoded['hasgrade'], isTrue);
      expect(MoodleQuizBestGrade.fromJson(encoded).grade, 12.5);
    });
  });
}
