// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classroom_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClassroomOptionJson _$ClassroomOptionJsonFromJson(Map<String, dynamic> json) =>
    ClassroomOptionJson(
      code: json['code'] as String,
      name: json['name'] as String,
    );

Map<String, dynamic> _$ClassroomOptionJsonToJson(
        ClassroomOptionJson instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
    };

ClassroomCampusJson _$ClassroomCampusJsonFromJson(Map<String, dynamic> json) =>
    ClassroomCampusJson(
      code: json['code'] as String,
      name: json['name'] as String,
      buildings: (json['buildings'] as List<dynamic>?)
              ?.map((e) =>
                  ClassroomOptionJson.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ClassroomCampusJsonToJson(
        ClassroomCampusJson instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'buildings': instance.buildings.map((e) => e.toJson()).toList(),
    };
