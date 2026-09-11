// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_gradereport_overview_course_grades.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleOverviewGradesEntity _$MoodleOverviewGradesEntityFromJson(
        Map<String, dynamic> json) =>
    MoodleOverviewGradesEntity(
      grades: (json['grades'] as List<dynamic>?)
              ?.map((e) =>
                  MoodleOverviewGrade.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleOverviewGradesEntityToJson(
        MoodleOverviewGradesEntity instance) =>
    <String, dynamic>{
      'grades': instance.grades.map((e) => e.toJson()).toList(),
    };

MoodleOverviewGrade _$MoodleOverviewGradeFromJson(Map<String, dynamic> json) =>
    MoodleOverviewGrade(
      courseid: (json['courseid'] as num?)?.toInt() ?? 0,
      grade: json['grade'] as String? ?? '',
    );

Map<String, dynamic> _$MoodleOverviewGradeToJson(
        MoodleOverviewGrade instance) =>
    <String, dynamic>{
      'courseid': instance.courseid,
      'grade': instance.grade,
    };

MoodleCourseGradeList _$MoodleCourseGradeListFromJson(
        Map<String, dynamic> json) =>
    MoodleCourseGradeList(
      semester: json['semester'] == null
          ? null
          : SemesterJson.fromJson(json['semester'] as Map<String, dynamic>),
      courses: (json['courses'] as List<dynamic>?)
              ?.map((e) =>
                  MoodleCourseGradeItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleCourseGradeListToJson(
        MoodleCourseGradeList instance) =>
    <String, dynamic>{
      'semester': instance.semester.toJson(),
      'courses': instance.courses.map((e) => e.toJson()).toList(),
    };

MoodleCourseGradeItem _$MoodleCourseGradeItemFromJson(
        Map<String, dynamic> json) =>
    MoodleCourseGradeItem(
      courseId: json['courseId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
    );

Map<String, dynamic> _$MoodleCourseGradeItemToJson(
        MoodleCourseGradeItem instance) =>
    <String, dynamic>{
      'courseId': instance.courseId,
      'name': instance.name,
      'grade': instance.grade,
    };
