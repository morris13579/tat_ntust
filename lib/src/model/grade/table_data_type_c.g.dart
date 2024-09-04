// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_data_type_c.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TableDataTypeCEntity _$TableDataTypeCEntityFromJson(
        Map<String, dynamic> json) =>
    TableDataTypeCEntity(
      LeaderEntity.fromJson(json['leader'] as Map<String, dynamic>),
      (json['parentcategories'] as List).map((e) => int.parse(e.toString())).toList(),
    );

Map<String, dynamic> _$TableDataTypeCEntityToJson(
    TableDataTypeCEntity instance) =>
    <String, dynamic>{
      'leader': instance.leader,
      'parentcategories': instance.parentcategories,
    };
