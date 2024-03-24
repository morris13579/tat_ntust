// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_gradereport_user_get_grades_table.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleGradeReportUserGetGradesTable
    _$MoodleGradeReportUserGetGradesTableFromJson(Map<String, dynamic> json) =>
        MoodleGradeReportUserGetGradesTable(
          tables: (json['tables'] as List<dynamic>?)
              ?.map((e) => Tables.fromJson(e as Map<String, dynamic>))
              .toList(),
          warnings: json['warnings'] as List<dynamic>?,
        );

Map<String, dynamic> _$MoodleGradeReportUserGetGradesTableToJson(
        MoodleGradeReportUserGetGradesTable instance) =>
    <String, dynamic>{
      'tables': instance.tables,
      'warnings': instance.warnings,
    };

Tables _$TablesFromJson(Map<String, dynamic> json) => Tables(
      courseId: json['courseid'] as int? ?? 0,
      userid: json['userid'] as int? ?? 0,
      userFullName: json['userfullname'] as String? ?? "",
      maxDepth: json['maxdepth'] as int? ?? 0,
      tableData: (json['tabledata'] as List<dynamic>?)
          ?.where((element) => element.length != 0)
          .map((e) => TableData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TablesToJson(Tables instance) => <String, dynamic>{
      'courseid': instance.courseId,
      'userid': instance.userid,
      'userfullname': instance.userFullName,
      'maxdepth': instance.maxDepth,
      'tabledata': instance.tableData,
    };

TableData _$TableDataFromJson(Map<String, dynamic> json) => TableData(
      itemName: json['itemname'] == null
          ? null
          : ItemName.fromJson(json['itemname'] as Map<String, dynamic>),
      leader: json['leader'] == null
          ? null
          : Leader.fromJson(json['leader'] as Map<String, dynamic>),
      weight: json['weight'] == null
          ? null
          : Weight.fromJson(json['weight'] as Map<String, dynamic>),
      grade: json['grade'] == null
          ? null
          : Grade.fromJson(json['grade'] as Map<String, dynamic>),
      range: json['range'] == null
          ? null
          : Range.fromJson(json['range'] as Map<String, dynamic>),
      percentage: json['percentage'] == null
          ? null
          : Percentage.fromJson(json['percentage'] as Map<String, dynamic>),
      feedback: json['feedback'] == null
          ? null
          : Feedback.fromJson(json['feedback'] as Map<String, dynamic>),
      contributiontocoursetotal: json['contributiontocoursetotal'] == null
          ? null
          : ContributionToCourseTotal.fromJson(
              json['contributiontocoursetotal'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TableDataToJson(TableData instance) => <String, dynamic>{
      'itemname': instance.itemName,
      'leader': instance.leader,
      'weight': instance.weight,
      'grade': instance.grade,
      'range': instance.range,
      'percentage': instance.percentage,
      'feedback': instance.feedback,
      'contributiontocoursetotal': instance.contributiontocoursetotal,
    };

ItemName _$ItemNameFromJson(Map<String, dynamic> json) => ItemName(
      classs: json['class'] as String? ?? "",
      colSpan: json['colspan'] as int? ?? 0,
      content: json['content'] as String? ?? "",
      cellType: json['celltype'] as String? ?? "",
      id: json['id'] as String? ?? "",
    );

Map<String, dynamic> _$ItemNameToJson(ItemName instance) => <String, dynamic>{
      'class': instance.classs,
      'colspan': instance.colSpan,
      'content': instance.content,
      'celltype': instance.cellType,
      'id': instance.id,
    };

Leader _$LeaderFromJson(Map<String, dynamic> json) => Leader(
      classs: json['class'] as String? ?? "",
      rowspan: json['rowspan'] as int? ?? 0,
    );

Map<String, dynamic> _$LeaderToJson(Leader instance) => <String, dynamic>{
      'class': instance.classs,
      'rowspan': instance.rowspan,
    };

Weight _$WeightFromJson(Map<String, dynamic> json) => Weight(
      classs: json['class'] as String? ?? "",
      content: json['content'] as String? ?? "",
      headers: json['headers'] as String? ?? "",
    );

Map<String, dynamic> _$WeightToJson(Weight instance) => <String, dynamic>{
      'class': instance.classs,
      'content': instance.content,
      'headers': instance.headers,
    };

Grade _$GradeFromJson(Map<String, dynamic> json) => Grade(
      classs: json['class'] as String? ?? "",
      content: json['content'] as String? ?? "",
      headers: json['headers'] as String? ?? "",
    );

Map<String, dynamic> _$GradeToJson(Grade instance) => <String, dynamic>{
      'class': instance.classs,
      'content': instance.content,
      'headers': instance.headers,
    };

Range _$RangeFromJson(Map<String, dynamic> json) => Range(
      classs: json['class'] as String? ?? "",
      content: json['content'] as String? ?? "",
      headers: json['headers'] as String? ?? "",
    );

Map<String, dynamic> _$RangeToJson(Range instance) => <String, dynamic>{
      'class': instance.classs,
      'content': instance.content,
      'headers': instance.headers,
    };

Percentage _$PercentageFromJson(Map<String, dynamic> json) => Percentage(
      classs: json['class'] as String? ?? "",
      content: json['content'] as String? ?? "",
      headers: json['headers'] as String? ?? "",
    );

Map<String, dynamic> _$PercentageToJson(Percentage instance) =>
    <String, dynamic>{
      'class': instance.classs,
      'content': instance.content,
      'headers': instance.headers,
    };

Feedback _$FeedbackFromJson(Map<String, dynamic> json) => Feedback(
      classs: json['class'] as String? ?? "",
      content: json['content'] as String? ?? "",
      headers: json['headers'] as String? ?? "",
    );

Map<String, dynamic> _$FeedbackToJson(Feedback instance) => <String, dynamic>{
      'class': instance.classs,
      'content': instance.content,
      'headers': instance.headers,
    };

ContributionToCourseTotal _$ContributionToCourseTotalFromJson(
        Map<String, dynamic> json) =>
    ContributionToCourseTotal(
      classs: json['class'] as String? ?? "",
      content: json['content'] as String? ?? "",
      headers: json['headers'] as String? ?? "",
    );

Map<String, dynamic> _$ContributionToCourseTotalToJson(
        ContributionToCourseTotal instance) =>
    <String, dynamic>{
      'class': instance.classs,
      'content': instance.content,
      'headers': instance.headers,
    };
