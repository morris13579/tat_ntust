import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sprintf/sprintf.dart';

part 'course_main_extra_json.g.dart';

List<CourseExtraInfoJson> getEntityList(List<dynamic> list) {
  List<CourseExtraInfoJson> result = [];
  for (var item in list) {
    result.add(CourseExtraInfoJson.fromJson(item));
  }
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
      {this.semester = "",
      this.courseNo = "",
      this.courseName = "",
      this.courseTeacher = "",
      this.creditPoint = "",
      this.courseTimes = "",
      this.practicalTimes = "",
      this.requireOption = "",
      this.allYear = "",
      this.chooseStudent = "",
      this.threeStudent = "",
      this.allStudent = "",
      this.restrict1 = "",
      this.restrict2 = "",
      this.nTURestrict = "",
      this.nTNURestrict = "",
      this.classRoomNo = "",
      this.coreAbility = "",
      this.courseURL = "",
      this.courseObject = "",
      this.courseContent = "",
      this.courseTextbook = "",
      this.courseRefbook = "",
      this.courseNote = "",
      this.courseGrading = "",
      this.courseRemark = ""});

  bool get isEmpty {
    return semester.isEmpty;
  }

  factory CourseExtraInfoJson.fromJson(Map<String, dynamic> srcJson) =>
      _$CourseExtraInfoJsonFromJson(srcJson);

  Map<String, dynamic> toJson() => _$CourseExtraInfoJsonToJson(this);
}

@JsonSerializable()
class CourseMainInfoJson {
  late CourseMainJson course;
  late List<TeacherJson> teacher; //開課老師
  late List<ClassroomJson> classroom; //使用教室
  late List<ClassJson> openClass; //開課班級
  CourseMainInfoJson(
      {CourseMainJson? course,
      List<TeacherJson>? teacher,
      List<ClassroomJson>? classroom,
      List<ClassJson>? openClass}) {
    this.course = course ?? CourseMainJson();
    this.teacher = teacher ?? [];
    this.classroom = classroom ?? [];
    this.openClass = openClass ?? [];
  }

  String getOpenClassName() {
    String name = "";
    for (ClassJson value in openClass) {
      name += '${value.name} ';
    }
    return name;
  }

  /// 多位老師以空白隔開。
  ///
  /// **結尾要 trim。** 一門課可能掛著一筆名字是空字串的老師（querycourse 沒給
  /// 就是空的），那時候組出來的是單一個空白——`isNotEmpty` 會是真，畫面上卻
  /// 什麼都沒有，於是多排一格空位出來。呼叫端本來各自補 `.trim()`，在來源
  /// 收乾淨就不必每一處都記得。
  String getTeacherName() => _joinNames(teacher.map((e) => e.name));

  /// 多間教室以空白隔開。空字串的原因與 [getTeacherName] 同一個。
  String getClassroomName() => _joinNames(classroom.map((e) => e.name));

  /// 過濾掉空的，再以單一空白接起來。
  static String _joinNames(Iterable<String> names) =>
      names.map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');

  bool get isEmpty {
    return course.isEmpty &&
        teacher.isEmpty &&
        classroom.isEmpty &&
        openClass.isEmpty;
  }

  @override
  String toString() {
    return sprintf(
        "---------course--------         \n%s \n"
        "---------teacherList--------    \n%s \n"
        "---------classroomList--------  \n%s \n"
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
