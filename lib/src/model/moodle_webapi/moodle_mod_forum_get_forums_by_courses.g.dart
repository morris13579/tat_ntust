// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_mod_forum_get_forums_by_courses.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleForum _$MoodleForumFromJson(Map<String, dynamic> json) => MoodleForum(
      id: (json['id'] as num?)?.toInt() ?? 0,
      course: (json['course'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      cmid: (json['cmid'] as num?)?.toInt() ?? 0,
      numdiscussions: (json['numdiscussions'] as num?)?.toInt() ?? 0,
      cancreatediscussions: json['cancreatediscussions'] as bool?,
      maxattachments: (json['maxattachments'] as num?)?.toInt() ?? 0,
      maxbytes: (json['maxbytes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MoodleForumToJson(MoodleForum instance) =>
    <String, dynamic>{
      'id': instance.id,
      'course': instance.course,
      'type': instance.type,
      'name': instance.name,
      'cmid': instance.cmid,
      'numdiscussions': instance.numdiscussions,
      'cancreatediscussions': instance.cancreatediscussions,
      'maxattachments': instance.maxattachments,
      'maxbytes': instance.maxbytes,
    };
