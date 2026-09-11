// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_mod_quiz_get_user_best_grade.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleQuizBestGrade _$MoodleQuizBestGradeFromJson(Map<String, dynamic> json) =>
    MoodleQuizBestGrade(
      hasgrade: json['hasgrade'] as bool? ?? false,
      grade: json['grade'] as num?,
      gradetopass: json['gradetopass'] as num?,
    );

Map<String, dynamic> _$MoodleQuizBestGradeToJson(
        MoodleQuizBestGrade instance) =>
    <String, dynamic>{
      'hasgrade': instance.hasgrade,
      'grade': instance.grade,
      'gradetopass': instance.gradetopass,
    };
