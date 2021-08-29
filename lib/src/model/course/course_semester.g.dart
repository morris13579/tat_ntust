// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_semester.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseSemesterJson _$CourseSemesterJsonFromJson(Map<String, dynamic> json) {
  return CourseSemesterJson(
    json['Semester'] as String,
    json['Static'] as bool,
    json['LoginEnable'] as bool,
    json['ShowRemind'] as bool,
    json['CurrentSemester'] as bool,
  );
}

Map<String, dynamic> _$CourseSemesterJsonToJson(CourseSemesterJson instance) =>
    <String, dynamic>{
      'Semester': instance.semester,
      'Static': instance.static,
      'LoginEnable': instance.loginEnable,
      'ShowRemind': instance.showRemind,
      'CurrentSemester': instance.currentSemester,
    };
