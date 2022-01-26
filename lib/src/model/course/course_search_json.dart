import 'package:json_annotation/json_annotation.dart';

part 'course_search_json.g.dart';

List<CourseSearchJson> getCourseSearchJsonList(List<dynamic> list) {
  List<CourseSearchJson> result = [];
  list.forEach((item) {
    result.add(CourseSearchJson.fromJson(item));
  });
  return result;
}

@JsonSerializable()
class CourseSearchJson {
  @JsonKey(name: 'Semester')
  String semester;

  @JsonKey(name: 'CourseNo')
  String courseNo;

  @JsonKey(name: 'CourseName')
  String courseName;

  @JsonKey(name: 'CourseTeacher')
  String courseTeacher;

  @JsonKey(name: 'Dimension')
  String dimension;

  @JsonKey(name: 'CreditPoint')
  String creditPoint;

  @JsonKey(name: 'RequireOption')
  String requireOption;

  @JsonKey(name: 'AllYear')
  String allYear;

  @JsonKey(name: 'ChooseStudent')
  int chooseStudent;

  @JsonKey(name: 'Restrict1')
  String restrict1;

  @JsonKey(name: 'Restrict2')
  String restrict2;

  @JsonKey(name: 'ThreeStudent')
  int threeStudent;

  @JsonKey(name: 'AllStudent')
  int allStudent;

  @JsonKey(name: 'NTURestrict')
  String nTURestrict;

  @JsonKey(name: 'NTNURestrict')
  String nTNURestrict;

  @JsonKey(name: 'CourseTimes')
  String courseTimes;

  @JsonKey(name: 'PracticalTimes')
  String practicalTimes;

  @JsonKey(name: 'ClassRoomNo')
  String classRoomNo;

  @JsonKey(name: 'Node')
  String node;

  @JsonKey(name: 'Contents')
  String contents;

  CourseSearchJson({
    this.semester: "",
    this.courseNo: "",
    this.courseName: "",
    this.courseTeacher: "",
    this.dimension: "",
    this.creditPoint: "",
    this.requireOption: "",
    this.allYear: "",
    this.chooseStudent: 0,
    this.restrict1: "",
    this.restrict2: "",
    this.threeStudent: 0,
    this.allStudent: 0,
    this.nTURestrict: "",
    this.nTNURestrict: "",
    this.courseTimes: "",
    this.practicalTimes: "",
    this.classRoomNo: "",
    this.node: "",
    this.contents: "",
  });

  factory CourseSearchJson.fromJson(Map<String, dynamic> srcJson) =>
      _$CourseSearchJsonFromJson(srcJson);
}
