import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_best_grade.dart';

/// test/fixtures/moodle_quiz/ 底下的 JSON。形狀照 MOODLE_405_STABLE 的
/// mod/quiz/classes/external.php，帶著所有 TAT 不建模的欄位（review*、
/// preferredbehaviour、sumgrades、gradeitemmarks……），解析時必須被忽略而不是拋。
Map<String, dynamic> loadMoodleQuizFixture(String name) =>
    json.decode(File('test/fixtures/moodle_quiz/$name.json').readAsStringSync())
        as Map<String, dynamic>;

/// `get_quizzes.json` 剝出來的兩份測驗（伺服器順序）。
///
/// 走 connector 的 `quizzesOf` 而不是直接 fromJson：正式路徑上 repository
/// 拿到（並寫進快取）的就是它的輸出，`name` 已還原 HTML 實體。
List<MoodleQuiz> fixtureQuizzes() =>
    MoodleWebApiConnector.quizzesOf(loadMoodleQuizFixture('get_quizzes'))!;

/// 同上，走 `quizAttemptsOf`：preview 的那幾筆已被濾掉。
List<MoodleQuizAttempt> fixtureAttempts(String name) =>
    MoodleWebApiConnector.quizAttemptsOf(loadMoodleQuizFixture(name))!;

MoodleQuizBestGrade fixtureBestGrade(String name) =>
    MoodleWebApiConnector.quizBestGradeOf(loadMoodleQuizFixture(name))!;

/// 原始 fromJson，沒有經過 connector 的還原。給模型的解析契約用。
MoodleQuiz rawFixtureQuiz(int index) =>
    MoodleModQuizGetQuizzesByCourses.fromJson(
            loadMoodleQuizFixture('get_quizzes'))
        .quizzes[index];
