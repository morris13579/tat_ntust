// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnnouncementJson _$AnnouncementJsonFromJson(Map<String, dynamic> json) =>
    AnnouncementJson(
      countDown: json['count_down'] as int,
      list: (json['list'] as List<dynamic>)
          .map((e) => AnnouncementInfoJson.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AnnouncementJsonToJson(AnnouncementJson instance) =>
    <String, dynamic>{
      'count_down': instance.countDown,
      'list': instance.list,
    };

AnnouncementInfoJson _$AnnouncementInfoJsonFromJson(
        Map<String, dynamic> json) =>
    AnnouncementInfoJson(
      title: json['title'] as String,
      content: json['content'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      test: json['test'] as bool,
    );

Map<String, dynamic> _$AnnouncementInfoJsonToJson(
        AnnouncementInfoJson instance) =>
    <String, dynamic>{
      'title': instance.title,
      'content': instance.content,
      'start_time': instance.startTime.toIso8601String(),
      'end_time': instance.endTime.toIso8601String(),
      'test': instance.test,
    };
