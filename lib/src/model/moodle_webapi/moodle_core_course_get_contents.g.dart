// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_core_course_get_contents.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleCoreCourseGetContents _$MoodleCoreCourseGetContentsFromJson(
        Map<String, dynamic> json) =>
    MoodleCoreCourseGetContents(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? "",
      summary: json['summary'] as String? ?? "",
      summaryformat: json['summaryformat'] as int? ?? 0,
      visible: json['visible'] as int? ?? 0,
      modules: (json['modules'] as List<dynamic>?)
          ?.map((e) => Modules.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MoodleCoreCourseGetContentsToJson(
        MoodleCoreCourseGetContents instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'visible': instance.visible,
      'summary': instance.summary,
      'summaryformat': instance.summaryformat,
      'modules': instance.modules,
    };

Modules _$ModulesFromJson(Map<String, dynamic> json) => Modules(
      id: json['id'] as int? ?? 0,
      url: json['url'] as String? ?? "",
      name: json['name'] as String? ?? "",
      instance: json['instance'] as int? ?? 0,
      description: json['description'] as String? ?? "",
      visible: json['visible'] as int? ?? 0,
      modicon: json['modicon'] as String? ?? "",
      modname: json['modname'] as String? ?? "",
      modplural: json['modplural'] as String? ?? "",
      indent: json['indent'] as int? ?? 0,
      folderIsNone: json['folderIsNone'] as bool? ?? false,
      contents: (json['contents'] as List<dynamic>?)
          ?.map((e) => Contents.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ModulesToJson(Modules instance) => <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'name': instance.name,
      'instance': instance.instance,
      'description': instance.description,
      'visible': instance.visible,
      'modicon': instance.modicon,
      'modname': instance.modname,
      'modplural': instance.modplural,
      'indent': instance.indent,
      'contents': instance.contents,
      'folderIsNone': instance.folderIsNone,
    };

Contents _$ContentsFromJson(Map<String, dynamic> json) => Contents(
      type: json['type'] as String? ?? "",
      filename: json['filename'] as String? ?? "",
      filepath: json['filepath'] as String? ?? "",
      filesize: json['filesize'] as int? ?? 0,
      fileurl: json['fileurl'] as String? ?? "",
      timecreated: json['timecreated'] as int? ?? 0,
      timemodified: json['timemodified'] as int? ?? 0,
      sortorder: json['sortorder'] as int? ?? 0,
      userid: json['userid'] as int? ?? 0,
      author: json['author'] as String? ?? "",
      license: json['license'] as String? ?? "",
    );

Map<String, dynamic> _$ContentsToJson(Contents instance) => <String, dynamic>{
      'type': instance.type,
      'filename': instance.filename,
      'filepath': instance.filepath,
      'filesize': instance.filesize,
      'fileurl': instance.fileurl,
      'timecreated': instance.timecreated,
      'timemodified': instance.timemodified,
      'sortorder': instance.sortorder,
      'userid': instance.userid,
      'author': instance.author,
      'license': instance.license,
    };
