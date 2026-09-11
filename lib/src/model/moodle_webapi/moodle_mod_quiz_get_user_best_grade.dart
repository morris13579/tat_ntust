import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_mod_quiz_get_user_best_grade.g.dart';

/// `mod_quiz_get_user_best_grade` 的回應。
///
/// `hasgrade == false` 涵蓋「沒作答過」、「老師關掉分數顯示」與「評分為 null」
/// 三種情況，伺服器沒有再細分的訊號，畫面一律當「尚未有成績」。
@JsonSerializable(explicitToJson: true)
class MoodleQuizBestGrade {
  /// 唯一必填的欄位，快取解碼拿它當形狀的標記。
  @JsonKey(name: 'hasgrade', defaultValue: false)
  bool hasgrade;

  /// 只有 [hasgrade] 為真時才在。PARAM_FLOAT，所以是 num 不是 double。
  @JsonKey(name: 'grade')
  num? grade;

  /// 站台設了非零的及格分數時才在；缺席代表沒有設，不是 0。
  @JsonKey(name: 'gradetopass')
  num? gradetopass;

  MoodleQuizBestGrade({
    this.hasgrade = false,
    this.grade,
    this.gradetopass,
  });

  bool get hasGradeToPass => gradetopass != null;

  factory MoodleQuizBestGrade.fromJson(Map<String, dynamic> json) =>
      _$MoodleQuizBestGradeFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleQuizBestGradeToJson(this);

  @override
  String toString() => jsonEncode(this);
}
