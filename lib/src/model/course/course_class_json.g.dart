// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_class_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseMainJson _$CourseMainJsonFromJson(Map<String, dynamic> json) =>
    CourseMainJson(
      name: json['name'] as String? ?? "",
      href: json['href'] as String? ?? "",
      id: json['id'] as String? ?? "",
      credits: json['credits'] as String? ?? "",
      hours: json['hours'] as String? ?? "",
      note: json['note'] as String? ?? "",
      category: json['category'] as String? ?? "",
      time: (json['time'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry($enumDecode(_$DayEnumMap, k), e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$CourseMainJsonToJson(CourseMainJson instance) =>
    <String, dynamic>{
      'name': instance.name,
      'id': instance.id,
      'href': instance.href,
      'note': instance.note,
      'credits': instance.credits,
      'hours': instance.hours,
      'category': instance.category,
      'time': instance.time.map((k, e) => MapEntry(_$DayEnumMap[k], e)),
    };

const _$DayEnumMap = {
  Day.monday: 'monday',
  Day.tuesday: 'tuesday',
  Day.wednesday: 'wednesday',
  Day.thursday: 'thursday',
  Day.friday: 'friday',
  Day.saturday: 'saturday',
  Day.sunday: 'sunday',
  Day.unKnown: 'unKnown',
};

CourseExtraJson _$CourseExtraJsonFromJson(Map<String, dynamic> json) =>
    CourseExtraJson(
      id: json['id'] as String? ?? "",
      openClass: json['openClass'] as String? ?? "",
      name: json['name'] as String? ?? "",
      category: json['category'] as String? ?? "",
      selectNumber: json['selectNumber'] as String? ?? "",
      withdrawNumber: json['withdrawNumber'] as String? ?? "",
      href: json['href'] as String? ?? "",
    );

Map<String, dynamic> _$CourseExtraJsonToJson(CourseExtraJson instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'href': instance.href,
      'category': instance.category,
      'selectNumber': instance.selectNumber,
      'withdrawNumber': instance.withdrawNumber,
      'openClass': instance.openClass,
    };

ClassJson _$ClassJsonFromJson(Map<String, dynamic> json) => ClassJson(
      name: json['name'] as String? ?? "",
      href: json['href'] as String? ?? "",
    );

Map<String, dynamic> _$ClassJsonToJson(ClassJson instance) => <String, dynamic>{
      'name': instance.name,
      'href': instance.href,
    };

ClassroomJson _$ClassroomJsonFromJson(Map<String, dynamic> json) =>
    ClassroomJson(
      name: json['name'] as String? ?? "",
      href: json['href'] as String? ?? "",
      mainUse: json['mainUse'] as bool? ?? false,
    );

Map<String, dynamic> _$ClassroomJsonToJson(ClassroomJson instance) =>
    <String, dynamic>{
      'name': instance.name,
      'href': instance.href,
      'mainUse': instance.mainUse,
    };

TeacherJson _$TeacherJsonFromJson(Map<String, dynamic> json) => TeacherJson(
      name: json['name'] as String? ?? "",
      href: json['href'] as String? ?? "",
    );

Map<String, dynamic> _$TeacherJsonToJson(TeacherJson instance) =>
    <String, dynamic>{
      'name': instance.name,
      'href': instance.href,
    };

SemesterJson _$SemesterJsonFromJson(Map<String, dynamic> json) => SemesterJson(
      year: json['year'] as String? ?? "",
      semester: json['semester'] as String? ?? "",
      urlPath: json['urlPath'] as String? ?? "",
    );

Map<String, dynamic> _$SemesterJsonToJson(SemesterJson instance) =>
    <String, dynamic>{
      'year': instance.year,
      'semester': instance.semester,
      'urlPath': instance.urlPath,
    };

ClassmateJson _$ClassmateJsonFromJson(Map<String, dynamic> json) =>
    ClassmateJson(
      className: json['className'] as String? ?? "",
      studentEnglishName: json['studentEnglishName'] as String? ?? "",
      studentName: json['studentName'] as String? ?? "",
      studentId: json['studentId'] as String? ?? "",
      isSelect: json['isSelect'] as bool? ?? false,
      href: json['href'] as String? ?? "",
    );

Map<String, dynamic> _$ClassmateJsonToJson(ClassmateJson instance) =>
    <String, dynamic>{
      'className': instance.className,
      'studentEnglishName': instance.studentEnglishName,
      'studentName': instance.studentName,
      'studentId': instance.studentId,
      'href': instance.href,
      'isSelect': instance.isSelect,
    };
