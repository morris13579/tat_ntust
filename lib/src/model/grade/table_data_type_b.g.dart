// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_data_type_b.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TableDataTypeBEntity _$TableDataTypeBEntityFromJson(
        Map<String, dynamic> json) =>
    TableDataTypeBEntity(
      json['itemname'] == null
          ? null
          : ItemNameEntity.fromJson(json['itemname'] as Map<String, dynamic>),
      WeightEntity.fromJson(json['weight'] as Map<String, dynamic>),
      WeightEntity.fromJson(json['grade'] as Map<String, dynamic>),
      WeightEntity.fromJson(json['range'] as Map<String, dynamic>),
      WeightEntity.fromJson(json['percentage'] as Map<String, dynamic>),
      WeightEntity.fromJson(json['feedback'] as Map<String, dynamic>),
      WeightEntity.fromJson(
          json['contributiontocoursetotal'] as Map<String, dynamic>),
      (json['parentcategories'] as List)
          .map((e) => int.parse(e.toString()))
          .toList(),
    );

Map<String, dynamic> _$TableDataTypeBEntityToJson(
        TableDataTypeBEntity instance) =>
    <String, dynamic>{
      'itemname': instance.itemName,
      'weight': instance.weight,
      'grade': instance.grade,
      'range': instance.range,
      'percentage': instance.percentage,
      'feedback': instance.feedback,
      'contributiontocoursetotal': instance.contributionToCourseTotal,
      'parentcategories': instance.parentcategories,
    };
