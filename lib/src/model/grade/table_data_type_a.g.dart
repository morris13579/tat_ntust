// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_data_type_a.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TableDataTypeAEntity _$TableDataTypeAEntityFromJson(
        Map<String, dynamic> json) =>
    TableDataTypeAEntity(
      json['itemname'] == null
          ? null
          : ItemNameEntity.fromJson(json['itemname'] as Map<String, dynamic>),
      LeaderEntity.fromJson(json['leader'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TableDataTypeAEntityToJson(
        TableDataTypeAEntity instance) =>
    <String, dynamic>{
      'itemname': instance.itemName,
      'leader': instance.leader,
    };
