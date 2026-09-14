import 'package:flutter_app/generated/core_api.g.dart';
import 'package:flutter_app/src/auth/auth_session.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_best_grade.dart';
import 'package:flutter_app/src/native/quiz_bridge.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fake_auth_session.dart';
import '../helpers/reset_statics.dart';
import '../helpers/test_l10n.dart';

class _FakeMoodle extends MoodleRepository {
  Result<MoodleQuiz> quiz = const Failed(FetchFailed());
  Result<List<MoodleQuizAttempt>> attempts = const Failed(FetchFailed());
  Result<MoodleQuizBestGrade> grade = const Failed(FetchFailed());
  final List<bool> backgrounds = [];

  @override
  Future<Result<MoodleQuiz>> getQuiz(String courseId, int quizId) async =>
      quiz;

  @override
  Future<Result<List<MoodleQuizAttempt>>> getQuizAttempts(int quizId,
      {bool background = false}) async {
    backgrounds.add(background);
    return attempts;
  }

  @override
  Future<Result<MoodleQuizBestGrade>> getQuizBestGrade(int quizId,
      {bool background = false}) async {
    backgrounds.add(background);
    return grade;
  }
}

/// 原生版的測驗詳情。開放時間怎麼說、次數用完了沒、成績怎麼格式化都是 Dart 的判斷。
void main() {
  setUpAll(() async {
    await loadTestL10n();
    await initializeDateFormatting();
  });

  final now = DateTime(2026, 9, 16, 10);
  late _FakeMoodle moodle;
  late QuizBridge bridge;

  setUp(() {
    resetAppStatics();
    AuthSession.instance = FakeAuthSession();
    moodle = _FakeMoodle();
    MoodleRepository.instance = moodle;
    bridge = QuizBridge(now: () => now);
  });

  tearDown(() => MoodleRepository.instance = MoodleRepository());

  MoodleQuiz quiz() => MoodleQuiz(
        id: 3,
        coursemodule: 30,
        name: '小考',
        timeopen: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/
            1000,
        timeclose:
            now.add(const Duration(days: 2)).millisecondsSinceEpoch ~/ 1000,
        timelimit: 1800,
        attempts: 2,
        grademethod: 1,
        decimalpoints: 1,
        grade: 10,
      );

  test('進頁時次要的兩支走背景；開放時間、規則、次數與成績照 Flutter 版的說法', () async {
    moodle.quiz = Ok(quiz());
    moodle.attempts = Ok([
      MoodleQuizAttempt(attempt: 1, state: 'finished', timefinish: 1),
      MoodleQuizAttempt(attempt: 2, state: 'finished', timefinish: 2),
    ]);
    moodle.grade = Ok(MoodleQuizBestGrade(hasgrade: true, grade: 8, gradetopass: 6));

    final detail = (await bridge.detail('CS1', 3, false)).detail!;

    expect(moodle.backgrounds, [true, true]);
    expect((detail.windowTone, detail.windowHint), (QuizWindowTone.open, '2 天後關閉'));
    expect(detail.rules.map((r) => r.value), ['30 分鐘', '2', '最高分']);
    expect((detail.attemptsChipLabel, detail.attemptsChipTone),
        ('已用 2 / 2 次', StatusTone.overdue));
    expect((detail.bestGrade, detail.gradeToPass), ('8.0 / 10.0', '6.0'));
    expect(detail.attempts.map((a) => a.title), ['第 2 次作答', '第 1 次作答']);
  });

  test('重新整理是使用者按的：次要的兩支也要能問使用者', () async {
    moodle.quiz = Ok(quiz());

    await bridge.detail('CS1', 3, true);

    expect(moodle.backgrounds, [false, false]);
  });

  test('作答紀錄與成績抓不到只影響那兩段；測驗本體抓不到才是整頁錯誤', () async {
    moodle.quiz = Ok(quiz());
    moodle.attempts = const Failed(FetchFailed('紀錄抓不到'));
    moodle.grade = const Failed(FetchFailed('成績抓不到'));

    final detail = (await bridge.detail('CS1', 3, false)).detail!;
    expect((detail.attemptsError, detail.gradeError), ('紀錄抓不到', '成績抓不到'));
    expect(detail.attemptsChipLabel, isNull);

    moodle.quiz = const Failed(FetchFailed('測驗抓不到'));
    final failed = await bridge.detail('CS1', 3, false);
    expect((failed.detail, failed.error), (null, '測驗抓不到'));
  });
}
