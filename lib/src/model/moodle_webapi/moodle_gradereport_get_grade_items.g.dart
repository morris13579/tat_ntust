// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_gradereport_get_grade_items.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleGradeItemsEntity _$MoodleGradeItemsEntityFromJson(
        Map<String, dynamic> json) =>
    MoodleGradeItemsEntity(
      userGrades: (json['usergrades'] as List<dynamic>?)
              ?.map((e) =>
                  MoodleUserGradesEntity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      warnings: json['warnings'] as List<dynamic>? ?? [],
    );

Map<String, dynamic> _$MoodleGradeItemsEntityToJson(
        MoodleGradeItemsEntity instance) =>
    <String, dynamic>{
      'usergrades': instance.userGrades.map((e) => e.toJson()).toList(),
      'warnings': instance.warnings,
    };

MoodleUserGradesEntity _$MoodleUserGradesEntityFromJson(
        Map<String, dynamic> json) =>
    MoodleUserGradesEntity(
      courseId: (json['courseid'] as num?)?.toInt() ?? 0,
      courseIdNumber: json['courseidnumber'] as String? ?? '',
      userId: (json['userid'] as num?)?.toInt() ?? 0,
      userFullName: json['userfullname'] as String? ?? '',
      userIdNumber: json['useridnumber'] as String? ?? '',
      maxDepth: (json['maxdepth'] as num?)?.toInt() ?? 0,
      gradeItems: (json['gradeitems'] as List<dynamic>?)
              ?.map((e) =>
                  MoodleGradeItemEntity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$MoodleUserGradesEntityToJson(
        MoodleUserGradesEntity instance) =>
    <String, dynamic>{
      'courseid': instance.courseId,
      'courseidnumber': instance.courseIdNumber,
      'userid': instance.userId,
      'userfullname': instance.userFullName,
      'useridnumber': instance.userIdNumber,
      'maxdepth': instance.maxDepth,
      'gradeitems': instance.gradeItems.map((e) => e.toJson()).toList(),
    };

MoodleGradeItemEntity _$MoodleGradeItemEntityFromJson(
        Map<String, dynamic> json) =>
    MoodleGradeItemEntity(
      id: (json['id'] as num?)?.toInt() ?? 0,
      itemName: json['itemname'] as String?,
      itemType: json['itemtype'] as String? ?? '',
      itemModule: json['itemmodule'] as String?,
      itemInstance: (json['iteminstance'] as num?)?.toInt(),
      itemNumber: (json['itemnumber'] as num?)?.toInt(),
      idNumber: json['idnumber'] as String?,
      categoryId: (json['categoryid'] as num?)?.toInt(),
      cmid: (json['cmid'] as num?)?.toInt(),
      weightRaw: json['weightraw'] as num?,
      weightFormatted: json['weightformatted'] as String? ?? '',
      gradeRaw: json['graderaw'] as num?,
      gradeDateSubmitted: (json['gradedatesubmitted'] as num?)?.toInt(),
      gradeDateGraded: (json['gradedategraded'] as num?)?.toInt(),
      gradeHiddenByDate: json['gradehiddenbydate'] as bool? ?? false,
      gradeNeedsUpdate: json['gradeneedsupdate'] as bool? ?? false,
      gradeIsHidden: json['gradeishidden'] as bool? ?? false,
      gradeFormatted: json['gradeformatted'] as String? ?? '',
      gradeMin: json['grademin'] as num?,
      gradeMax: json['grademax'] as num?,
      rangeFormatted: json['rangeformatted'] as String? ?? '',
      percentageFormatted: json['percentageformatted'] as String? ?? '',
      feedback: json['feedback'] as String? ?? '',
      feedbackFormat: (json['feedbackformat'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MoodleGradeItemEntityToJson(
        MoodleGradeItemEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'itemname': instance.itemName,
      'itemtype': instance.itemType,
      'itemmodule': instance.itemModule,
      'iteminstance': instance.itemInstance,
      'itemnumber': instance.itemNumber,
      'idnumber': instance.idNumber,
      'categoryid': instance.categoryId,
      'cmid': instance.cmid,
      'weightraw': instance.weightRaw,
      'weightformatted': instance.weightFormatted,
      'graderaw': instance.gradeRaw,
      'gradedatesubmitted': instance.gradeDateSubmitted,
      'gradedategraded': instance.gradeDateGraded,
      'gradehiddenbydate': instance.gradeHiddenByDate,
      'gradeneedsupdate': instance.gradeNeedsUpdate,
      'gradeishidden': instance.gradeIsHidden,
      'gradeformatted': instance.gradeFormatted,
      'grademin': instance.gradeMin,
      'grademax': instance.gradeMax,
      'rangeformatted': instance.rangeFormatted,
      'percentageformatted': instance.percentageFormatted,
      'feedback': instance.feedback,
      'feedbackformat': instance.feedbackFormat,
    };
