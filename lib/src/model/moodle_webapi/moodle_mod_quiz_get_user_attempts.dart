import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_mod_quiz_get_user_attempts.g.dart';

/// `mod_quiz_get_user_attempts`（Moodle 5.0 起改名為
/// `mod_quiz_get_user_quiz_attempts`）的回應，兩支的形狀一模一樣。
///
/// `state` 是開放集合：新那一支在 5.0 站台上還會回 `notstarted` 與
/// `submitted`，解析在 `MoodleQuizUtils.attemptStateOf`。
@JsonSerializable(explicitToJson: true)
class MoodleModQuizGetUserAttempts {
  @JsonKey(name: 'attempts', defaultValue: [])
  List<MoodleQuizAttempt> attempts;

  MoodleModQuizGetUserAttempts({
    List<MoodleQuizAttempt>? attempts,
  }) : attempts = attempts ?? <MoodleQuizAttempt>[];

  factory MoodleModQuizGetUserAttempts.fromJson(Map<String, dynamic> json) =>
      _$MoodleModQuizGetUserAttemptsFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleModQuizGetUserAttemptsToJson(this);

  @override
  String toString() => jsonEncode(this);
}

/// 一次作答紀錄。`sumgrades` 刻意不建模：學生端只要不是 finished、或老師關掉
/// 分數顯示，伺服器就把它抹成 null，畫面用的是 `get_user_best_grade` 那一個數字。
@JsonSerializable(explicitToJson: true)
class MoodleQuizAttempt {
  @JsonKey(name: 'id', defaultValue: 0)
  int id;

  /// 第幾次作答，1 起算。
  @JsonKey(name: 'attempt', defaultValue: 0)
  int attempt;

  @JsonKey(name: 'state', defaultValue: "")
  String state;

  @JsonKey(name: 'preview', defaultValue: 0)
  int preview;

  @JsonKey(name: 'timestart', defaultValue: 0)
  int timestart;

  /// 0 = 還沒送出。
  @JsonKey(name: 'timefinish', defaultValue: 0)
  int timefinish;

  MoodleQuizAttempt({
    this.id = 0,
    this.attempt = 0,
    this.state = "",
    this.preview = 0,
    this.timestart = 0,
    this.timefinish = 0,
  });

  bool get isPreview => preview != 0;

  bool get hasFinished => timefinish > 0;

  factory MoodleQuizAttempt.fromJson(Map<String, dynamic> json) =>
      _$MoodleQuizAttemptFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleQuizAttemptToJson(this);

  @override
  String toString() => jsonEncode(this);
}
