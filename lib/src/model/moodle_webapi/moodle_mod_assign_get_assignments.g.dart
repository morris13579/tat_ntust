// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_mod_assign_get_assignments.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleModAssignGetAssignments _$MoodleModAssignGetAssignmentsFromJson(
        Map<String, dynamic> json) =>
    MoodleModAssignGetAssignments(
      courses: (json['courses'] as List<dynamic>?)
              ?.map(
                  (e) => MoodleAssignCourse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleModAssignGetAssignmentsToJson(
        MoodleModAssignGetAssignments instance) =>
    <String, dynamic>{
      'courses': instance.courses.map((e) => e.toJson()).toList(),
    };

MoodleAssignCourse _$MoodleAssignCourseFromJson(Map<String, dynamic> json) =>
    MoodleAssignCourse(
      assignments: (json['assignments'] as List<dynamic>?)
              ?.map((e) => MoodleAssignment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleAssignCourseToJson(MoodleAssignCourse instance) =>
    <String, dynamic>{
      'assignments': instance.assignments.map((e) => e.toJson()).toList(),
    };

MoodleAssignment _$MoodleAssignmentFromJson(Map<String, dynamic> json) =>
    MoodleAssignment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      cmid: (json['cmid'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      duedate: (json['duedate'] as num?)?.toInt() ?? 0,
      allowsubmissionsfromdate:
          (json['allowsubmissionsfromdate'] as num?)?.toInt() ?? 0,
      cutoffdate: (json['cutoffdate'] as num?)?.toInt() ?? 0,
      nosubmissions: (json['nosubmissions'] as num?)?.toInt() ?? 0,
      teamsubmission: (json['teamsubmission'] as num?)?.toInt() ?? 0,
      requireallteammemberssubmit:
          (json['requireallteammemberssubmit'] as num?)?.toInt() ?? 0,
      preventsubmissionnotingroup:
          (json['preventsubmissionnotingroup'] as num?)?.toInt() ?? 0,
      submissiondrafts: (json['submissiondrafts'] as num?)?.toInt() ?? 0,
      requiresubmissionstatement:
          (json['requiresubmissionstatement'] as num?)?.toInt() ?? 0,
      submissionstatement: json['submissionstatement'] as String?,
      maxattempts: (json['maxattempts'] as num?)?.toInt() ?? -1,
      attemptreopenmethod: json['attemptreopenmethod'] as String? ?? '',
      timelimit: (json['timelimit'] as num?)?.toInt() ?? 0,
      blindmarking: (json['blindmarking'] as num?)?.toInt() ?? 0,
      configs: (json['configs'] as List<dynamic>?)
              ?.map(
                  (e) => MoodleAssignConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      intro: json['intro'] as String?,
      introattachments: (json['introattachments'] as List<dynamic>?)
              ?.map((e) => MoodleAssignFile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleAssignmentToJson(MoodleAssignment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'cmid': instance.cmid,
      'name': instance.name,
      'duedate': instance.duedate,
      'allowsubmissionsfromdate': instance.allowsubmissionsfromdate,
      'cutoffdate': instance.cutoffdate,
      'nosubmissions': instance.nosubmissions,
      'teamsubmission': instance.teamsubmission,
      'requireallteammemberssubmit': instance.requireallteammemberssubmit,
      'preventsubmissionnotingroup': instance.preventsubmissionnotingroup,
      'submissiondrafts': instance.submissiondrafts,
      'requiresubmissionstatement': instance.requiresubmissionstatement,
      'submissionstatement': instance.submissionstatement,
      'maxattempts': instance.maxattempts,
      'attemptreopenmethod': instance.attemptreopenmethod,
      'timelimit': instance.timelimit,
      'blindmarking': instance.blindmarking,
      'configs': instance.configs.map((e) => e.toJson()).toList(),
      'intro': instance.intro,
      'introattachments':
          instance.introattachments.map((e) => e.toJson()).toList(),
    };

MoodleAssignConfig _$MoodleAssignConfigFromJson(Map<String, dynamic> json) =>
    MoodleAssignConfig(
      plugin: json['plugin'] as String? ?? '',
      subtype: json['subtype'] as String? ?? '',
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );

Map<String, dynamic> _$MoodleAssignConfigToJson(MoodleAssignConfig instance) =>
    <String, dynamic>{
      'plugin': instance.plugin,
      'subtype': instance.subtype,
      'name': instance.name,
      'value': instance.value,
    };

MoodleAssignFile _$MoodleAssignFileFromJson(Map<String, dynamic> json) =>
    MoodleAssignFile(
      filename: json['filename'] as String? ?? '',
      fileurl: json['fileurl'] as String? ?? '',
      filepath: json['filepath'] as String? ?? '/',
      mimetype: json['mimetype'] as String? ?? '',
      filesize: (json['filesize'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MoodleAssignFileToJson(MoodleAssignFile instance) =>
    <String, dynamic>{
      'filename': instance.filename,
      'fileurl': instance.fileurl,
      'filepath': instance.filepath,
      'mimetype': instance.mimetype,
      'filesize': instance.filesize,
    };
