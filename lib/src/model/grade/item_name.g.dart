// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_name.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ItemNameEntity _$ItemNameEntityFromJson(Map<String, dynamic> json) =>
    ItemNameEntity(
      json['class'] as String,
      json['colspan'] as int,
      json['content'] as String,
      json['celltype'] as String,
      json['id'] as String,
    );

Map<String, dynamic> _$ItemNameEntityToJson(ItemNameEntity instance) =>
    <String, dynamic>{
      'class': instance.class_,
      'colspan': instance.colspan,
      'content': instance.content,
      'celltype': instance.celltype,
      'id': instance.id,
    };
