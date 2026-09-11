import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_best_grade.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/repository/result.dart';
import 'package:get/get.dart';

/// 測驗頁的狀態：測驗本體、作答紀錄與最佳成績；由頁面的 State 建立與 [dispose]。
class CourseQuizController {
  CourseQuizController({
    required this.courseId,
    required this.quizId,
    MoodleQuiz? quiz,
  }) : quiz = Rxn(quiz == null ? null : Ok(quiz));

  final String courseId;
  final int quizId;

  final Rxn<Result<MoodleQuiz>> quiz;
  final attempts = Rxn<Result<List<MoodleQuizAttempt>>>();
  final bestGrade = Rxn<Result<MoodleQuizBestGrade>>();

  /// 三個一起發：頁面一開就要，序列發會讓成績慢一整個 RTT。
  /// 兩支次要的走 `background`：一次網路失敗會讓三支同時失敗，而重試框沒有
  /// 去重，使用者得連關三個才看得到畫面——那兩個區塊自己就有就地重試。
  Future<void> loadAll() => Future.wait([
        if (quiz.value == null) loadQuiz(),
        loadAttempts(background: true),
        loadBestGrade(background: true),
      ]);

  Future<void> loadQuiz() async {
    quiz.value = null;
    quiz.value = await MoodleRepository.instance.getQuiz(courseId, quizId);
  }

  Future<void> loadAttempts({bool background = false}) async {
    attempts.value = null;
    attempts.value = await MoodleRepository.instance
        .getQuizAttempts(quizId, background: background);
  }

  Future<void> loadBestGrade({bool background = false}) async {
    bestGrade.value = null;
    bestGrade.value = await MoodleRepository.instance
        .getQuizBestGrade(quizId, background: background);
  }

  void dispose() {
    quiz.close();
    attempts.close();
    bestGrade.close();
  }
}
