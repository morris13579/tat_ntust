// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_mod_forum_get_forum_access_information.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleForumAccess _$MoodleForumAccessFromJson(Map<String, dynamic> json) =>
    MoodleForumAccess(
      cancreateattachment: json['cancreateattachment'] as bool?,
      candeleteownpost: json['candeleteownpost'] as bool?,
      canreplypost: json['canreplypost'] as bool?,
      canstartdiscussion: json['canstartdiscussion'] as bool?,
    );

Map<String, dynamic> _$MoodleForumAccessToJson(MoodleForumAccess instance) =>
    <String, dynamic>{
      'cancreateattachment': instance.cancreateattachment,
      'candeleteownpost': instance.candeleteownpost,
      'canreplypost': instance.canreplypost,
      'canstartdiscussion': instance.canstartdiscussion,
    };
