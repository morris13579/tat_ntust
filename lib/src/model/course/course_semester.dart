import 'package:json_annotation/json_annotation.dart';

part 'course_semester.g.dart';


List<CourseSemesterJson> getCourseSemesterList(List<dynamic> list){
  List<CourseSemesterJson> result = [];
  list.forEach((item){
    result.add(CourseSemesterJson.fromJson(item));
  });
  return result;
}

@JsonSerializable()
class CourseSemesterJson extends Object{

  @JsonKey(name: 'Semester')
  String semester;

  @JsonKey(name: 'Static')
  bool static;

  @JsonKey(name: 'LoginEnable')
  bool loginEnable;

  @JsonKey(name: 'ShowRemind')
  bool showRemind;

  @JsonKey(name: 'CurrentSemester')
  bool currentSemester;

  CourseSemesterJson(this.semester,this.static,this.loginEnable,this.showRemind,this.currentSemester,);

  factory CourseSemesterJson.fromJson(Map<String, dynamic> srcJson) => _$CourseSemesterJsonFromJson(srcJson);

}
