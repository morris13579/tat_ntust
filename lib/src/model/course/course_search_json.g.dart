// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_search_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseSearchJson _$CourseSearchJsonFromJson(Map<String, dynamic> json) =>
    CourseSearchJson(
      semester: json['Semester'] as String? ?? "",
      courseNo: json['CourseNo'] as String? ?? "",
      courseName: json['CourseName'] as String? ?? "",
      courseTeacher: json['CourseTeacher'] as String? ?? "",
      dimension: json['Dimension'] as String? ?? "",
      creditPoint: json['CreditPoint'] as String? ?? "",
      requireOption: json['RequireOption'] as String? ?? "",
      allYear: json['AllYear'] as String? ?? "",
      chooseStudent: json['ChooseStudent'] as int? ?? 0,
      restrict1: json['Restrict1'] as String? ?? "",
      restrict2: json['Restrict2'] as String? ?? "",
      threeStudent: json['ThreeStudent'] as int? ?? 0,
      allStudent: json['AllStudent'] as int? ?? 0,
      nTURestrict: json['NTURestrict'] as String? ?? "",
      nTNURestrict: json['NTNURestrict'] as String? ?? "",
      courseTimes: json['CourseTimes'] as String? ?? "",
      practicalTimes: json['PracticalTimes'] as String? ?? "",
      classRoomNo: json['ClassRoomNo'] as String? ?? "",
      node: json['Node'] as String? ?? "",
      contents: json['Contents'] as String? ?? "",
    );

Map<String, dynamic> _$CourseSearchJsonToJson(CourseSearchJson instance) =>
    <String, dynamic>{
      'Semester': instance.semester,
      'CourseNo': instance.courseNo,
      'CourseName': instance.courseName,
      'CourseTeacher': instance.courseTeacher,
      'Dimension': instance.dimension,
      'CreditPoint': instance.creditPoint,
      'RequireOption': instance.requireOption,
      'AllYear': instance.allYear,
      'ChooseStudent': instance.chooseStudent,
      'Restrict1': instance.restrict1,
      'Restrict2': instance.restrict2,
      'ThreeStudent': instance.threeStudent,
      'AllStudent': instance.allStudent,
      'NTURestrict': instance.nTURestrict,
      'NTNURestrict': instance.nTNURestrict,
      'CourseTimes': instance.courseTimes,
      'PracticalTimes': instance.practicalTimes,
      'ClassRoomNo': instance.classRoomNo,
      'Node': instance.node,
      'Contents': instance.contents,
    };
