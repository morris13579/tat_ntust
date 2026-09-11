import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_mod_quiz_get_quizzes_by_courses.g.dart';

/// `mod_quiz_get_quizzes_by_courses` 的回應。時間與次數欄位伺服器已套過
/// `quiz_update_effective_access`，含使用者與群組的 override，App 不必再算。
/// 只宣告有人讀的欄位——未宣告的 key 不會進 `cache_moodle_quiz` 那包 blob。
@JsonSerializable(explicitToJson: true)
class MoodleModQuizGetQuizzesByCourses {
  /// 與 `mod_assign_get_assignments` 不同：測驗是最上層的平坦陣列，沒有
  /// `courses[]` 那一層。
  @JsonKey(name: 'quizzes', defaultValue: [])
  List<MoodleQuiz> quizzes;

  MoodleModQuizGetQuizzesByCourses({
    List<MoodleQuiz>? quizzes,
  }) : quizzes = quizzes ?? <MoodleQuiz>[];

  factory MoodleModQuizGetQuizzesByCourses.fromJson(
          Map<String, dynamic> json) =>
      _$MoodleModQuizGetQuizzesByCoursesFromJson(json);

  Map<String, dynamic> toJson() =>
      _$MoodleModQuizGetQuizzesByCoursesToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// 一份測驗（`quizzes[]` 的元素），只留畫面要用的欄位。
@JsonSerializable(explicitToJson: true)
class MoodleQuiz {
  /// quiz instance id；`mod_quiz_get_user_attempts` 的 `quizid` 吃它。
  @JsonKey(name: 'id', defaultValue: 0)
  int id;

  /// course module id；網頁的 `mod/quiz/view.php?id=` 吃它。
  @JsonKey(name: 'coursemodule', defaultValue: 0)
  int coursemodule;

  /// connector 的 `quizzesOf` 已 HtmlUtils.clean 還原成純文字。
  @JsonKey(name: 'name', defaultValue: "")
  String name;

  /// 進得到這一頁就一定有 `mod/quiz:view`，所以 null 當空字串就好，
  /// 不像 `MoodleAssignment.intro` 有「刻意藏起來」那一態。
  @JsonKey(name: 'intro')
  String? intro;

  /// Unix 秒，0 = 沒有限制。
  @JsonKey(name: 'timeopen', defaultValue: 0)
  int timeopen;

  @JsonKey(name: 'timeclose', defaultValue: 0)
  int timeclose;

  /// 每次作答的時限（秒），0 = 沒有時限。
  @JsonKey(name: 'timelimit', defaultValue: 0)
  int timelimit;

  /// 可作答次數，0 = 不限次數。
  @JsonKey(name: 'attempts', defaultValue: 0)
  int attempts;

  /// QUIZ_GRADEHIGHEST(1)…QUIZ_ATTEMPTLAST(4)，見 [MoodleQuizUtils]。
  @JsonKey(name: 'grademethod', defaultValue: 0)
  int grademethod;

  /// 站台沒送時照 Moodle 自己的 `quiz | decimalpoints` 預設值。
  @JsonKey(name: 'decimalpoints', defaultValue: 2)
  int decimalpoints;

  /// 總分（滿分）。PARAM_FLOAT 可能是 `10` 也可能是 `10.5`，所以是 num。
  @JsonKey(name: 'grade')
  num? grade;

  MoodleQuiz({
    this.id = 0,
    this.coursemodule = 0,
    this.name = "",
    this.intro,
    this.timeopen = 0,
    this.timeclose = 0,
    this.timelimit = 0,
    this.attempts = 0,
    this.grademethod = 0,
    this.decimalpoints = 2,
    this.grade,
  });

  /// `quizaccess_numattempts::make`：0 就是不限次數。
  bool get isUnlimitedAttempts => attempts == 0;

  bool get hasTimeLimit => timelimit > 0;

  bool get hasOpenWindow => timeopen > 0 || timeclose > 0;

  factory MoodleQuiz.fromJson(Map<String, dynamic> json) =>
      _$MoodleQuizFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleQuizToJson(this);

  @override
  String toString() => jsonEncode(this);
}
