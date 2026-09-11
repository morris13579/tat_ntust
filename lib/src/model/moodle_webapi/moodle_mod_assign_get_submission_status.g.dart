// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_mod_assign_get_submission_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleAssignSubmissionStatus _$MoodleAssignSubmissionStatusFromJson(
        Map<String, dynamic> json) =>
    MoodleAssignSubmissionStatus(
      lastattempt: json['lastattempt'] == null
          ? null
          : MoodleAssignLastAttempt.fromJson(
              json['lastattempt'] as Map<String, dynamic>),
      feedback: json['feedback'] == null
          ? null
          : MoodleAssignFeedback.fromJson(
              json['feedback'] as Map<String, dynamic>),
      previousattempts: (json['previousattempts'] as List<dynamic>?)
              ?.map((e) => MoodleAssignPreviousAttempt.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleAssignSubmissionStatusToJson(
        MoodleAssignSubmissionStatus instance) =>
    <String, dynamic>{
      'lastattempt': instance.lastattempt?.toJson(),
      'feedback': instance.feedback?.toJson(),
      'previousattempts':
          instance.previousattempts.map((e) => e.toJson()).toList(),
    };

MoodleAssignLastAttempt _$MoodleAssignLastAttemptFromJson(
        Map<String, dynamic> json) =>
    MoodleAssignLastAttempt(
      submission: json['submission'] == null
          ? null
          : MoodleAssignSubmission.fromJson(
              json['submission'] as Map<String, dynamic>),
      teamsubmission: json['teamsubmission'] == null
          ? null
          : MoodleAssignSubmission.fromJson(
              json['teamsubmission'] as Map<String, dynamic>),
      extensionduedate: (json['extensionduedate'] as num?)?.toInt() ?? 0,
      gradingstatus: json['gradingstatus'] as String? ?? '',
      canedit: json['canedit'] == null ? false : _boolFromJson(json['canedit']),
      cansubmit:
          json['cansubmit'] == null ? false : _boolFromJson(json['cansubmit']),
      locked: json['locked'] == null ? false : _boolFromJson(json['locked']),
      graded: json['graded'] == null ? false : _boolFromJson(json['graded']),
      submissionsenabled: json['submissionsenabled'] == null
          ? false
          : _boolFromJson(json['submissionsenabled']),
      blindmarking: json['blindmarking'] == null
          ? false
          : _boolFromJson(json['blindmarking']),
      timelimit: (json['timelimit'] as num?)?.toInt() ?? 0,
      usergroups: (json['usergroups'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      submissiongroup: (json['submissiongroup'] as num?)?.toInt(),
      submissiongroupmemberswhoneedtosubmit:
          (json['submissiongroupmemberswhoneedtosubmit'] as List<dynamic>?)
                  ?.map((e) => (e as num).toInt())
                  .toList() ??
              [],
      caneditowner: json['caneditowner'] == null
          ? false
          : _boolFromJson(json['caneditowner']),
    );

Map<String, dynamic> _$MoodleAssignLastAttemptToJson(
        MoodleAssignLastAttempt instance) =>
    <String, dynamic>{
      'submission': instance.submission?.toJson(),
      'teamsubmission': instance.teamsubmission?.toJson(),
      'extensionduedate': instance.extensionduedate,
      'gradingstatus': instance.gradingstatus,
      'canedit': instance.canedit,
      'cansubmit': instance.cansubmit,
      'locked': instance.locked,
      'graded': instance.graded,
      'submissionsenabled': instance.submissionsenabled,
      'blindmarking': instance.blindmarking,
      'timelimit': instance.timelimit,
      'usergroups': instance.usergroups,
      'submissiongroup': instance.submissiongroup,
      'submissiongroupmemberswhoneedtosubmit':
          instance.submissiongroupmemberswhoneedtosubmit,
      'caneditowner': instance.caneditowner,
    };

MoodleAssignSubmission _$MoodleAssignSubmissionFromJson(
        Map<String, dynamic> json) =>
    MoodleAssignSubmission(
      timemodified: (json['timemodified'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      plugins: (json['plugins'] as List<dynamic>?)
              ?.map(
                  (e) => MoodleAssignPlugin.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      attemptnumber: (json['attemptnumber'] as num?)?.toInt() ?? 0,
      timestarted: (json['timestarted'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MoodleAssignSubmissionToJson(
        MoodleAssignSubmission instance) =>
    <String, dynamic>{
      'timemodified': instance.timemodified,
      'status': instance.status,
      'plugins': instance.plugins.map((e) => e.toJson()).toList(),
      'attemptnumber': instance.attemptnumber,
      'timestarted': instance.timestarted,
    };

MoodleAssignPreviousAttempt _$MoodleAssignPreviousAttemptFromJson(
        Map<String, dynamic> json) =>
    MoodleAssignPreviousAttempt(
      attemptnumber: (json['attemptnumber'] as num?)?.toInt() ?? 0,
      submission: json['submission'] == null
          ? null
          : MoodleAssignSubmission.fromJson(
              json['submission'] as Map<String, dynamic>),
      grade: json['grade'] == null
          ? null
          : MoodleAssignPreviousGrade.fromJson(
              json['grade'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MoodleAssignPreviousAttemptToJson(
        MoodleAssignPreviousAttempt instance) =>
    <String, dynamic>{
      'attemptnumber': instance.attemptnumber,
      'submission': instance.submission?.toJson(),
      'grade': instance.grade?.toJson(),
    };

MoodleAssignPreviousGrade _$MoodleAssignPreviousGradeFromJson(
        Map<String, dynamic> json) =>
    MoodleAssignPreviousGrade(
      grade: json['grade'] as String? ?? '',
      gradefordisplay: json['gradefordisplay'] as String? ?? '',
    );

Map<String, dynamic> _$MoodleAssignPreviousGradeToJson(
        MoodleAssignPreviousGrade instance) =>
    <String, dynamic>{
      'grade': instance.grade,
      'gradefordisplay': instance.gradefordisplay,
    };

MoodleAssignPlugin _$MoodleAssignPluginFromJson(Map<String, dynamic> json) =>
    MoodleAssignPlugin(
      type: json['type'] as String? ?? '',
      fileareas: (json['fileareas'] as List<dynamic>?)
              ?.map((e) =>
                  MoodleAssignFileArea.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      editorfields: (json['editorfields'] as List<dynamic>?)
              ?.map((e) =>
                  MoodleAssignEditorField.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleAssignPluginToJson(MoodleAssignPlugin instance) =>
    <String, dynamic>{
      'type': instance.type,
      'fileareas': instance.fileareas.map((e) => e.toJson()).toList(),
      'editorfields': instance.editorfields.map((e) => e.toJson()).toList(),
    };

MoodleAssignFileArea _$MoodleAssignFileAreaFromJson(
        Map<String, dynamic> json) =>
    MoodleAssignFileArea(
      files: (json['files'] as List<dynamic>?)
              ?.map((e) => MoodleAssignFile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleAssignFileAreaToJson(
        MoodleAssignFileArea instance) =>
    <String, dynamic>{
      'files': instance.files.map((e) => e.toJson()).toList(),
    };

MoodleAssignEditorField _$MoodleAssignEditorFieldFromJson(
        Map<String, dynamic> json) =>
    MoodleAssignEditorField(
      name: json['name'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );

Map<String, dynamic> _$MoodleAssignEditorFieldToJson(
        MoodleAssignEditorField instance) =>
    <String, dynamic>{
      'name': instance.name,
      'text': instance.text,
    };

MoodleAssignGrade _$MoodleAssignGradeFromJson(Map<String, dynamic> json) =>
    MoodleAssignGrade(
      grade: json['grade'] as String? ?? '',
    );

Map<String, dynamic> _$MoodleAssignGradeToJson(MoodleAssignGrade instance) =>
    <String, dynamic>{
      'grade': instance.grade,
    };

MoodleAssignFeedback _$MoodleAssignFeedbackFromJson(
        Map<String, dynamic> json) =>
    MoodleAssignFeedback(
      grade: json['grade'] == null
          ? null
          : MoodleAssignGrade.fromJson(json['grade'] as Map<String, dynamic>),
      gradefordisplay: json['gradefordisplay'] as String? ?? '',
      gradeddate: (json['gradeddate'] as num?)?.toInt(),
      plugins: (json['plugins'] as List<dynamic>?)
              ?.map(
                  (e) => MoodleAssignPlugin.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleAssignFeedbackToJson(
        MoodleAssignFeedback instance) =>
    <String, dynamic>{
      'grade': instance.grade?.toJson(),
      'gradefordisplay': instance.gradefordisplay,
      'gradeddate': instance.gradeddate,
      'plugins': instance.plugins.map((e) => e.toJson()).toList(),
    };
