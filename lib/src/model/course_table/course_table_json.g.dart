// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_table_json.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseTableJson _$CourseTableJsonFromJson(Map<String, dynamic> json) =>
    CourseTableJson(
      courseSemester: json['courseSemester'] == null
          ? null
          : SemesterJson.fromJson(
              json['courseSemester'] as Map<String, dynamic>),
      courseInfoMap: (json['courseInfoMap'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
            $enumDecode(_$DayEnumMap, k),
            (e as Map<String, dynamic>).map(
              (k, e) => MapEntry($enumDecode(_$SectionNumberEnumMap, k),
                  CourseInfoJson.fromJson(e as Map<String, dynamic>)),
            )),
      ),
      studentId: json['studentId'] as String? ?? "",
      studentName: json['studentName'] as String? ?? "",
    );

Map<String, dynamic> _$CourseTableJsonToJson(CourseTableJson instance) =>
    <String, dynamic>{
      'courseSemester': instance.courseSemester,
      'studentId': instance.studentId,
      'studentName': instance.studentName,
      'courseInfoMap': instance.courseInfoMap.map((k, e) => MapEntry(
          _$DayEnumMap[k],
          e.map((k, e) => MapEntry(_$SectionNumberEnumMap[k], e)))),
    };

const _$SectionNumberEnumMap = {
  SectionNumber.t_1: 'T_1',
  SectionNumber.t_2: 'T_2',
  SectionNumber.t_3: 'T_3',
  SectionNumber.t_4: 'T_4',
  SectionNumber.t_N: 'T_N',
  SectionNumber.t_5: 'T_5',
  SectionNumber.t_6: 'T_6',
  SectionNumber.t_7: 'T_7',
  SectionNumber.t_8: 'T_8',
  SectionNumber.t_9: 'T_9',
  SectionNumber.t_A: 'T_A',
  SectionNumber.t_B: 'T_B',
  SectionNumber.t_C: 'T_C',
  SectionNumber.t_D: 'T_D',
  SectionNumber.t_UnKnown: 'T_UnKnown',
};

const _$DayEnumMap = {
  Day.monday: 'Monday',
  Day.tuesday: 'Tuesday',
  Day.wednesday: 'Wednesday',
  Day.thursday: 'Thursday',
  Day.friday: 'Friday',
  Day.saturday: 'Saturday',
  Day.sunday: 'Sunday',
  Day.unKnown: 'UnKnown',
};

CourseInfoJson _$CourseInfoJsonFromJson(Map<String, dynamic> json) =>
    CourseInfoJson(
      main: json['main'] == null
          ? null
          : CourseMainInfoJson.fromJson(json['main'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CourseInfoJsonToJson(CourseInfoJson instance) =>
    <String, dynamic>{
      'main': instance.main,
    };
