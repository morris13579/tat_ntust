// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'score_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScoreRankJson _$ScoreRankJsonFromJson(Map<String, dynamic> json) =>
    ScoreRankJson(
      info: (json['info'] as List<dynamic>?)
          ?.map((e) => SemesterScoreJson.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ScoreRankJsonToJson(ScoreRankJson instance) =>
    <String, dynamic>{
      'info': instance.info,
    };

SemesterScoreJson _$SemesterScoreJsonFromJson(Map<String, dynamic> json) =>
    SemesterScoreJson(
      semester: SemesterJson.fromJson(json['semester'] as Map<String, dynamic>),
      item: (json['item'] as List<dynamic>)
          .map((e) => ScoreItemJson.fromJson(e as Map<String, dynamic>))
          .toList(),
      rank: json['rank'] == null
          ? null
          : RankJson.fromJson(json['rank'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SemesterScoreJsonToJson(SemesterScoreJson instance) =>
    <String, dynamic>{
      'semester': instance.semester,
      'item': instance.item,
      'rank': instance.rank,
    };

RankJson _$RankJsonFromJson(Map<String, dynamic> json) => RankJson(
      classRank: json['classRank'] as String,
      departmentRank: json['departmentRank'] as String,
      averageScore: json['averageScore'] as String,
      classRankYears: json['classRankYears'] as String,
      departmentRankYears: json['departmentRankYears'] as String,
      averageYears: json['averageYears'] as String,
    );

Map<String, dynamic> _$RankJsonToJson(RankJson instance) => <String, dynamic>{
      'classRank': instance.classRank,
      'departmentRank': instance.departmentRank,
      'averageScore': instance.averageScore,
      'classRankYears': instance.classRankYears,
      'departmentRankYears': instance.departmentRankYears,
      'averageYears': instance.averageYears,
    };

ScoreItemJson _$ScoreItemJsonFromJson(Map<String, dynamic> json) =>
    ScoreItemJson(
      courseId: json['courseId'] as String,
      score: json['score'] as String,
      name: json['name'] as String,
      credit: json['credit'] as String,
      generalDimension: json['generalDimension'] as String,
      remark: json['remark'] as String,
    );

Map<String, dynamic> _$ScoreItemJsonToJson(ScoreItemJson instance) =>
    <String, dynamic>{
      'courseId': instance.courseId,
      'name': instance.name,
      'credit': instance.credit,
      'score': instance.score,
      'remark': instance.remark,
      'generalDimension': instance.generalDimension,
    };
