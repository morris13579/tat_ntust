// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_user_picture.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleUpdatePictureResult _$MoodleUpdatePictureResultFromJson(
        Map<String, dynamic> json) =>
    MoodleUpdatePictureResult(
      success: json['success'] as bool? ?? false,
      profileimageurl: json['profileimageurl'] as String? ?? '',
    );

Map<String, dynamic> _$MoodleUpdatePictureResultToJson(
        MoodleUpdatePictureResult instance) =>
    <String, dynamic>{
      'success': instance.success,
      'profileimageurl': instance.profileimageurl,
    };

MoodleDraftFile _$MoodleDraftFileFromJson(Map<String, dynamic> json) =>
    MoodleDraftFile(
      itemid: (json['itemid'] as num?)?.toInt() ?? 0,
      filename: json['filename'] as String? ?? '',
      filepath: json['filepath'] as String? ?? '',
      filesize: (json['filesize'] as num?)?.toInt() ?? 0,
      error: json['error'] as String? ?? '',
      errortype: json['errortype'] as String? ?? '',
    );

Map<String, dynamic> _$MoodleDraftFileToJson(MoodleDraftFile instance) =>
    <String, dynamic>{
      'itemid': instance.itemid,
      'filename': instance.filename,
      'filepath': instance.filepath,
      'filesize': instance.filesize,
      'error': instance.error,
      'errortype': instance.errortype,
    };
