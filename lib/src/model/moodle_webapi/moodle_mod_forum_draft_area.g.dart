// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_mod_forum_draft_area.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleForumDraftFile _$MoodleForumDraftFileFromJson(
        Map<String, dynamic> json) =>
    MoodleForumDraftFile(
      filename: json['filename'] as String? ?? '',
      filepath: json['filepath'] as String? ?? '/',
      filesize: (json['filesize'] as num?)?.toInt() ?? 0,
      fileurl: json['fileurl'] as String? ?? '',
      mimetype: json['mimetype'] as String? ?? '',
    );

Map<String, dynamic> _$MoodleForumDraftFileToJson(
        MoodleForumDraftFile instance) =>
    <String, dynamic>{
      'filename': instance.filename,
      'filepath': instance.filepath,
      'filesize': instance.filesize,
      'fileurl': instance.fileurl,
      'mimetype': instance.mimetype,
    };
