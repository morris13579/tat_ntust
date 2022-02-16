// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleScoreItem _$MoodleScoreItemFromJson(Map<String, dynamic> json) =>
    MoodleScoreItem(
      name: json['name'] as String,
      weight: json['weight'] as String,
      score: json['score'] as String,
      fullRange: json['fullRange'] as String,
      percentage: json['percentage'] as String,
      feedback: json['feedback'] as String,
      contribute: json['contribute'] as String,
    );

Map<String, dynamic> _$MoodleScoreItemToJson(MoodleScoreItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'weight': instance.weight,
      'score': instance.score,
      'fullRange': instance.fullRange,
      'percentage': instance.percentage,
      'feedback': instance.feedback,
      'contribute': instance.contribute,
    };
