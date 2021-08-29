import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sprintf/sprintf.dart';

part 'course_main_extra_json.g.dart';

List<CourseExtraInfoJson> getEntityList(List<dynamic> list) {
  List<CourseExtraInfoJson> result = [];
  list.forEach((item) {
    result.add(CourseExtraInfoJson.fromJson(item));
  });
  return result;
}

@JsonSerializable()
class CourseExtraInfoJson extends Object {
  @JsonKey(name: 'Semester')
  String semester;

  @JsonKey(name: 'CourseNo')
  String courseNo;

  @JsonKey(name: 'CourseName')
  String courseName;

  @JsonKey(name: 'CourseTeacher')
  String courseTeacher;

  @JsonKey(name: 'CreditPoint')
  String creditPoint;

  @JsonKey(name: 'CourseTimes')
  String courseTimes;

  @JsonKey(name: 'PracticalTimes')
  String practicalTimes;

  @JsonKey(name: 'RequireOption')
  String requireOption;

  @JsonKey(name: 'AllYear')
  String allYear;

  @JsonKey(name: 'ChooseStudent')
  String chooseStudent;

  @JsonKey(name: 'ThreeStudent')
  String threeStudent;

  @JsonKey(name: 'AllStudent')
  String allStudent;

  @JsonKey(name: 'Restrict1')
  String restrict1;

  @JsonKey(name: 'Restrict2')
  String restrict2;

  @JsonKey(name: 'NTURestrict')
  String nTURestrict;

  @JsonKey(name: 'NTNURestrict')
  String nTNURestrict;

  @JsonKey(name: 'ClassRoomNo')
  String classRoomNo;

  @JsonKey(name: 'CoreAbility')
  String coreAbility;

  @JsonKey(name: 'CourseURL')
  String courseURL;

  @JsonKey(name: 'CourseObject')
  String courseObject;

  @JsonKey(name: 'CourseContent')
  String courseContent;

  @JsonKey(name: 'CourseTextbook')
  String courseTextbook;

  @JsonKey(name: 'CourseRefbook')
  String courseRefbook;

  @JsonKey(name: 'CourseNote')
  String courseNote;

  @JsonKey(name: 'CourseGrading')
  String courseGrading;

  @JsonKey(name: 'CourseRemark')
  String courseRemark;

  CourseExtraInfoJson(
      {this.semester,
      this.courseNo,
      this.courseName,
      this.courseTeacher,
      this.creditPoint,
      this.courseTimes,
      this.practicalTimes,
      this.requireOption,
      this.allYear,
      this.chooseStudent,
      this.threeStudent,
      this.allStudent,
      this.restrict1,
      this.restrict2,
      this.nTURestrict,
      this.nTNURestrict,
      this.classRoomNo,
      this.coreAbility,
      this.courseURL,
      this.courseObject,
      this.courseContent,
      this.courseTextbook,
      this.courseRefbook,
      this.courseNote,
      this.courseGrading,
      this.courseRemark});

  bool get isEmpty {
    return semester.isEmpty;
  }

  factory CourseExtraInfoJson.fromJson(Map<String, dynamic> srcJson) =>
      _$CourseExtraInfoJsonFromJson(srcJson);
}

@JsonSerializable()
class CourseMainInfoJson {
  CourseMainJson course;
  List<TeacherJson> teacher; //開課老師
  List<ClassroomJson> classroom; //使用教室
  List<ClassJson> openClass; //開課班級
  CourseMainInfoJson(
      {this.course, this.teacher, this.classroom, this.openClass}) {
    course = course ?? CourseMainJson();
    teacher = teacher ?? [];
    classroom = classroom ?? [];
    openClass = openClass ?? [];
  }

  String getOpenClassName() {
    String name = "";
    for (ClassJson value in openClass) {
      name += value.name + ' ';
    }
    return name;
  }

  String getTeacherName() {
    String name = "";
    for (TeacherJson value in teacher) {
      name += value.name + ' ';
    }
    return name;
  }

  String getClassroomName() {
    String name = "";
    for (ClassroomJson value in classroom) {
      name += value.name + ' ';
    }
    return name;
  }

  List<String> getClassroomNameList() {
    List<String> name = [];
    for (ClassroomJson value in classroom) {
      name.add(value.name);
    }
    return name;
  }

  List<String> getClassroomHrefList() {
    List<String> href = [];
    for (ClassroomJson value in classroom) {
      href.add(value.href);
    }
    return href;
  }

  String getTime() {
    String time = "";
    List<String> dayStringList = [
      R.current.Monday,
      R.current.Tuesday,
      R.current.Wednesday,
      R.current.Thursday,
      R.current.Friday,
      R.current.Saturday,
      R.current.Sunday,
      R.current.UnKnown
    ];
    for (Day day in course.time.keys) {
      if (course.time[day].replaceAll(RegExp('[|\n]'), "").isNotEmpty) {
        time += "${dayStringList[day.index]}_${course.time[day]} ";
      }
    }
    return time;
  }

  bool get isEmpty {
    return course.isEmpty &&
        teacher.length == 0 &&
        classroom.length == 0 &&
        openClass.length == 0;
  }

  @override
  String toString() {
    return sprintf(
        "---------course--------         \n%s \n" +
            "---------teacherList--------    \n%s \n" +
            "---------classroomList--------  \n%s \n" +
            "---------openClassList--------  \n%s \n",
        [
          course.toString(),
          teacher.toString(),
          classroom.toString(),
          openClass.toString()
        ]);
  }

  factory CourseMainInfoJson.fromJson(Map<String, dynamic> json) =>
      _$CourseMainInfoJsonFromJson(json);

  Map<String, dynamic> toJson() => _$CourseMainInfoJsonToJson(this);
}
