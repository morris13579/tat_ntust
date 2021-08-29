// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_main_extra_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseExtraInfoJson _$CourseExtraInfoJsonFromJson(Map<String, dynamic> json) {
  return CourseExtraInfoJson(
    semester: json['Semester'] as String,
    courseNo: json['CourseNo'] as String,
    courseName: json['CourseName'] as String,
    courseTeacher: json['CourseTeacher'] as String,
    creditPoint: json['CreditPoint'] as String,
    courseTimes: json['CourseTimes'] as String,
    practicalTimes: json['PracticalTimes'] as String,
    requireOption: json['RequireOption'] as String,
    allYear: json['AllYear'] as String,
    chooseStudent: json['ChooseStudent'] as String,
    threeStudent: json['ThreeStudent'] as String,
    allStudent: json['AllStudent'] as String,
    restrict1: json['Restrict1'] as String,
    restrict2: json['Restrict2'] as String,
    nTURestrict: json['NTURestrict'] as String,
    nTNURestrict: json['NTNURestrict'] as String,
    classRoomNo: json['ClassRoomNo'] as String,
    coreAbility: json['CoreAbility'] as String,
    courseURL: json['CourseURL'] as String,
    courseObject: json['CourseObject'] as String,
    courseContent: json['CourseContent'] as String,
    courseTextbook: json['CourseTextbook'] as String,
    courseRefbook: json['CourseRefbook'] as String,
    courseNote: json['CourseNote'] as String,
    courseGrading: json['CourseGrading'] as String,
    courseRemark: json['CourseRemark'] as String,
  );
}

Map<String, dynamic> _$CourseExtraInfoJsonToJson(
        CourseExtraInfoJson instance) =>
    <String, dynamic>{
      'Semester': instance.semester,
      'CourseNo': instance.courseNo,
      'CourseName': instance.courseName,
      'CourseTeacher': instance.courseTeacher,
      'CreditPoint': instance.creditPoint,
      'CourseTimes': instance.courseTimes,
      'PracticalTimes': instance.practicalTimes,
      'RequireOption': instance.requireOption,
      'AllYear': instance.allYear,
      'ChooseStudent': instance.chooseStudent,
      'ThreeStudent': instance.threeStudent,
      'AllStudent': instance.allStudent,
      'Restrict1': instance.restrict1,
      'Restrict2': instance.restrict2,
      'NTURestrict': instance.nTURestrict,
      'NTNURestrict': instance.nTNURestrict,
      'ClassRoomNo': instance.classRoomNo,
      'CoreAbility': instance.coreAbility,
      'CourseURL': instance.courseURL,
      'CourseObject': instance.courseObject,
      'CourseContent': instance.courseContent,
      'CourseTextbook': instance.courseTextbook,
      'CourseRefbook': instance.courseRefbook,
      'CourseNote': instance.courseNote,
      'CourseGrading': instance.courseGrading,
      'CourseRemark': instance.courseRemark,
    };

CourseMainInfoJson _$CourseMainInfoJsonFromJson(Map<String, dynamic> json) {
  return CourseMainInfoJson(
    course: json['course'] == null
        ? null
        : CourseMainJson.fromJson(json['course'] as Map<String, dynamic>),
    teacher: (json['teacher'] as List)
        ?.map((e) =>
            e == null ? null : TeacherJson.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    classroom: (json['classroom'] as List)
        ?.map((e) => e == null
            ? null
            : ClassroomJson.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    openClass: (json['openClass'] as List)
        ?.map((e) =>
            e == null ? null : ClassJson.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$CourseMainInfoJsonToJson(CourseMainInfoJson instance) =>
    <String, dynamic>{
      'course': instance.course,
      'teacher': instance.teacher,
      'classroom': instance.classroom,
      'openClass': instance.openClass,
    };
