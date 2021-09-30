import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:sprintf/sprintf.dart';

part 'setting_json.g.dart';

@JsonSerializable()
class SettingJson {
  late CourseSettingJson course;
  late OtherSettingJson other;

  SettingJson({CourseSettingJson? course, OtherSettingJson? other}) {
    this.course = course ?? CourseSettingJson();
    this.other = other ?? OtherSettingJson();
  }

  bool get isEmpty {
    return course.isEmpty && other.isEmpty;
  }

  @override
  String toString() {
    return sprintf(
        "---------course--------        \n%s \n" +
            "---------other--------         \n%s \n",
        [
          course.toString(),
          other.toString(),
        ]);
  }

  factory SettingJson.fromJson(Map<String, dynamic> json) =>
      _$SettingJsonFromJson(json);

  Map<String, dynamic> toJson() => _$SettingJsonToJson(this);
}

@JsonSerializable()
class CourseSettingJson {
  late CourseTableJson info;

  CourseSettingJson({CourseTableJson? info}) {
    this.info = info ?? CourseTableJson();
  }

  bool get isEmpty {
    return info.isEmpty;
  }

  @override
  String toString() {
    return sprintf(
        "---------courseInfo--------       :\n%s \n", [info.toString()]);
  }

  factory CourseSettingJson.fromJson(Map<String, dynamic> json) =>
      _$CourseSettingJsonFromJson(json);

  Map<String, dynamic> toJson() => _$CourseSettingJsonToJson(this);
}

@JsonSerializable()
class OtherSettingJson {
  String lang;
  bool autoCheckAppUpdate;
  bool useExternalVideoPlayer;
  bool useMoodleWebApi;

  OtherSettingJson(
      {this.lang = "",
      this.autoCheckAppUpdate = true,
      this.useExternalVideoPlayer = false,
      this.useMoodleWebApi = true});

  bool get isEmpty {
    return lang.isEmpty;
  }

  @override
  String toString() {
    return sprintf("lang      :%s \n ", [lang]);
  }

  factory OtherSettingJson.fromJson(Map<String, dynamic> json) =>
      _$OtherSettingJsonFromJson(json);

  Map<String, dynamic> toJson() => _$OtherSettingJsonToJson(this);
}
