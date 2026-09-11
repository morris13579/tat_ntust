// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_mod_quiz_get_quizzes_by_courses.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleModQuizGetQuizzesByCourses _$MoodleModQuizGetQuizzesByCoursesFromJson(
        Map<String, dynamic> json) =>
    MoodleModQuizGetQuizzesByCourses(
      quizzes: (json['quizzes'] as List<dynamic>?)
              ?.map((e) => MoodleQuiz.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleModQuizGetQuizzesByCoursesToJson(
        MoodleModQuizGetQuizzesByCourses instance) =>
    <String, dynamic>{
      'quizzes': instance.quizzes.map((e) => e.toJson()).toList(),
    };

MoodleQuiz _$MoodleQuizFromJson(Map<String, dynamic> json) => MoodleQuiz(
      id: (json['id'] as num?)?.toInt() ?? 0,
      coursemodule: (json['coursemodule'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      intro: json['intro'] as String?,
      timeopen: (json['timeopen'] as num?)?.toInt() ?? 0,
      timeclose: (json['timeclose'] as num?)?.toInt() ?? 0,
      timelimit: (json['timelimit'] as num?)?.toInt() ?? 0,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      grademethod: (json['grademethod'] as num?)?.toInt() ?? 0,
      decimalpoints: (json['decimalpoints'] as num?)?.toInt() ?? 2,
      grade: json['grade'] as num?,
    );

Map<String, dynamic> _$MoodleQuizToJson(MoodleQuiz instance) =>
    <String, dynamic>{
      'id': instance.id,
      'coursemodule': instance.coursemodule,
      'name': instance.name,
      'intro': instance.intro,
      'timeopen': instance.timeopen,
      'timeclose': instance.timeclose,
      'timelimit': instance.timelimit,
      'attempts': instance.attempts,
      'grademethod': instance.grademethod,
      'decimalpoints': instance.decimalpoints,
      'grade': instance.grade,
    };
