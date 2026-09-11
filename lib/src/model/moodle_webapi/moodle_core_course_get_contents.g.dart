// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_core_course_get_contents.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleCoreCourseGetContents _$MoodleCoreCourseGetContentsFromJson(
        Map<String, dynamic> json) =>
    MoodleCoreCourseGetContents(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? "",
      summary: json['summary'] as String? ?? "",
      summaryformat: (json['summaryformat'] as num?)?.toInt() ?? 0,
      visible: (json['visible'] as num?)?.toInt() ?? 0,
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
      id: (json['id'] as num?)?.toInt() ?? 0,
      url: json['url'] as String? ?? "",
      name: json['name'] as String? ?? "",
      instance: (json['instance'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? "",
      visible: (json['visible'] as num?)?.toInt() ?? 0,
      modicon: json['modicon'] as String? ?? "",
      modname: json['modname'] as String? ?? "",
      modplural: json['modplural'] as String? ?? "",
      indent: (json['indent'] as num?)?.toInt() ?? 0,
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
    };

Contents _$ContentsFromJson(Map<String, dynamic> json) => Contents(
      type: json['type'] as String? ?? "",
      filename: json['filename'] as String? ?? "",
      filepath: json['filepath'] as String? ?? "",
      filesize: (json['filesize'] as num?)?.toInt() ?? 0,
      fileurl: json['fileurl'] as String? ?? "",
      mimetype: json['mimetype'] as String? ?? "",
      timecreated: (json['timecreated'] as num?)?.toInt() ?? 0,
      timemodified: (json['timemodified'] as num?)?.toInt() ?? 0,
      sortorder: (json['sortorder'] as num?)?.toInt() ?? 0,
      userid: (json['userid'] as num?)?.toInt() ?? 0,
      author: json['author'] as String? ?? "",
      license: json['license'] as String? ?? "",
    );

Map<String, dynamic> _$ContentsToJson(Contents instance) => <String, dynamic>{
      'type': instance.type,
      'filename': instance.filename,
      'filepath': instance.filepath,
      'filesize': instance.filesize,
      'fileurl': instance.fileurl,
      'mimetype': instance.mimetype,
      'timecreated': instance.timecreated,
      'timemodified': instance.timemodified,
      'sortorder': instance.sortorder,
      'userid': instance.userid,
      'author': instance.author,
      'license': instance.license,
    };
