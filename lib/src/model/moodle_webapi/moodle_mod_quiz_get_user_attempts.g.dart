// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_mod_quiz_get_user_attempts.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleModQuizGetUserAttempts _$MoodleModQuizGetUserAttemptsFromJson(
        Map<String, dynamic> json) =>
    MoodleModQuizGetUserAttempts(
      attempts: (json['attempts'] as List<dynamic>?)
              ?.map(
                  (e) => MoodleQuizAttempt.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleModQuizGetUserAttemptsToJson(
        MoodleModQuizGetUserAttempts instance) =>
    <String, dynamic>{
      'attempts': instance.attempts.map((e) => e.toJson()).toList(),
    };

MoodleQuizAttempt _$MoodleQuizAttemptFromJson(Map<String, dynamic> json) =>
    MoodleQuizAttempt(
      id: (json['id'] as num?)?.toInt() ?? 0,
      attempt: (json['attempt'] as num?)?.toInt() ?? 0,
      state: json['state'] as String? ?? '',
      preview: (json['preview'] as num?)?.toInt() ?? 0,
      timestart: (json['timestart'] as num?)?.toInt() ?? 0,
      timefinish: (json['timefinish'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MoodleQuizAttemptToJson(MoodleQuizAttempt instance) =>
    <String, dynamic>{
      'id': instance.id,
      'attempt': instance.attempt,
      'state': instance.state,
      'preview': instance.preview,
      'timestart': instance.timestart,
      'timefinish': instance.timefinish,
    };
