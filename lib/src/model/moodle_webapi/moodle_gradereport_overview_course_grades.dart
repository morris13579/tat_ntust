import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:json_annotation/json_annotation.dart';

part 'moodle_gradereport_overview_course_grades.g.dart';

/// `gradereport_overview_get_course_grades` 的回應。`warnings` 伺服器端永遠是
/// 空陣列，不建模。
@JsonSerializable(explicitToJson: true)
class MoodleOverviewGradesEntity {
  @JsonKey(defaultValue: [])
  List<MoodleOverviewGrade> grades;

  MoodleOverviewGradesEntity({this.grades = const []});

  factory MoodleOverviewGradesEntity.fromJson(Map<String, dynamic> json) =>
      _$MoodleOverviewGradesEntityFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleOverviewGradesEntityToJson(this);
}

/// 一門課的目前總分。`rawgrade` 與 `rank` 刻意不建模：前者是未格式化的原始值
/// （沒有小數位設定、量尺與等第對照），後者要站台開了 showrank 才有。
@JsonSerializable()
class MoodleOverviewGrade {
  @JsonKey(defaultValue: 0)
  int courseid;

  /// 伺服器格式化好的字串。總分被藏起來或還沒有成績時是 "-"，
  /// 課程總分是文字/無評分型態時是空字串。一律不解析成數字。
  @JsonKey(defaultValue: '')
  String grade;

  MoodleOverviewGrade({this.courseid = 0, this.grade = ''});

  factory MoodleOverviewGrade.fromJson(Map<String, dynamic> json) =>
      _$MoodleOverviewGradeFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleOverviewGradeToJson(this);
}

/// 已經接上課名、只留目前學期的一份清單——寫進快取的就是這個形狀。
/// 課名對照表（`core_enrol_get_users_courses`）只活在記憶體裡，離線時接不
/// 起來，所以快取存的是接好的結果而不是原始回應。
@JsonSerializable(explicitToJson: true)
class MoodleCourseGradeList {
  late SemesterJson semester;

  @JsonKey(defaultValue: [])
  List<MoodleCourseGradeItem> courses;

  MoodleCourseGradeList({SemesterJson? semester, this.courses = const []}) {
    this.semester = semester ?? SemesterJson();
  }

  factory MoodleCourseGradeList.fromJson(Map<String, dynamic> json) =>
      _$MoodleCourseGradeListFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleCourseGradeListToJson(this);
}

/// 畫面上的一列。[courseId] 是去掉學年學期前綴的 NTUST 課號，點下去用它開
/// 課程頁（同 `CourseDataController` 收的那一個）。
@JsonSerializable()
class MoodleCourseGradeItem {
  @JsonKey(defaultValue: '')
  String courseId;

  @JsonKey(defaultValue: '')
  String name;

  @JsonKey(defaultValue: '')
  String grade;

  MoodleCourseGradeItem({
    this.courseId = '',
    this.name = '',
    this.grade = '',
  });

  factory MoodleCourseGradeItem.fromJson(Map<String, dynamic> json) =>
      _$MoodleCourseGradeItemFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleCourseGradeItemToJson(this);
}
