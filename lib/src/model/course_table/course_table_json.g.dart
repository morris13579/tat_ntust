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
          _$DayEnumMap[k]!,
          e.map((k, e) => MapEntry(_$SectionNumberEnumMap[k]!, e)))),
    };

const _$SectionNumberEnumMap = {
  SectionNumber.t_1: 't_1',
  SectionNumber.t_2: 't_2',
  SectionNumber.t_3: 't_3',
  SectionNumber.t_4: 't_4',
  SectionNumber.t_N: 't_N',
  SectionNumber.t_5: 't_5',
  SectionNumber.t_6: 't_6',
  SectionNumber.t_7: 't_7',
  SectionNumber.t_8: 't_8',
  SectionNumber.t_9: 't_9',
  SectionNumber.t_A: 't_A',
  SectionNumber.t_B: 't_B',
  SectionNumber.t_C: 't_C',
  SectionNumber.t_D: 't_D',
  SectionNumber.t_UnKnown: 't_UnKnown',
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
