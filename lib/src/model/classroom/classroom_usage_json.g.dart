// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classroom_usage_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClassroomSlotJson _$ClassroomSlotJsonFromJson(Map<String, dynamic> json) =>
    ClassroomSlotJson(
      course: json['course'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '',
      marked: json['marked'] as bool? ?? false,
    );

Map<String, dynamic> _$ClassroomSlotJsonToJson(ClassroomSlotJson instance) =>
    <String, dynamic>{
      'course': instance.course,
      'teacher': instance.teacher,
      'marked': instance.marked,
    };

ClassroomRowJson _$ClassroomRowJsonFromJson(Map<String, dynamic> json) =>
    ClassroomRowJson(
      name: json['name'] as String,
      slots: (json['slots'] as List<dynamic>)
          .map((e) => ClassroomSlotJson.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ClassroomRowJsonToJson(ClassroomRowJson instance) =>
    <String, dynamic>{
      'name': instance.name,
      'slots': instance.slots.map((e) => e.toJson()).toList(),
    };

ClassroomUsageJson _$ClassroomUsageJsonFromJson(Map<String, dynamic> json) =>
    ClassroomUsageJson(
      campusCode: json['campusCode'] as String,
      date: DateTime.parse(json['date'] as String),
      rooms: (json['rooms'] as List<dynamic>)
          .map((e) => ClassroomRowJson.fromJson(e as Map<String, dynamic>))
          .toList(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      buildingCode: json['buildingCode'] as String?,
    );

Map<String, dynamic> _$ClassroomUsageJsonToJson(ClassroomUsageJson instance) =>
    <String, dynamic>{
      'campusCode': instance.campusCode,
      'buildingCode': instance.buildingCode,
      'date': instance.date.toIso8601String(),
      'rooms': instance.rooms.map((e) => e.toJson()).toList(),
      'fetchedAt': instance.fetchedAt.toIso8601String(),
    };
