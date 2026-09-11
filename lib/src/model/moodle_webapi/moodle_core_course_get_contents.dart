library;

import 'package:json_annotation/json_annotation.dart';

part 'moodle_core_course_get_contents.g.dart';

@JsonSerializable()
class MoodleCoreCourseGetContents {
  @JsonKey(name: 'id')
  int id;

  @JsonKey(name: 'name')
  String name;

  @JsonKey(name: 'visible')
  int visible;

  @JsonKey(name: 'summary')
  String summary;

  @JsonKey(name: 'summaryformat')
  int summaryformat;

  @JsonKey(name: 'modules')
  late List<Modules> modules;

  MoodleCoreCourseGetContents(
      {this.id = 0,
      this.name = "",
      this.summary = "",
      this.summaryformat = 0,
      this.visible = 0,
      List<Modules>? modules}) {
    this.modules = modules ?? [];
  }

  factory MoodleCoreCourseGetContents.fromJson(Map<String, dynamic> srcJson) =>
      _$MoodleCoreCourseGetContentsFromJson(srcJson);

  Map<String, dynamic> toJson() => _$MoodleCoreCourseGetContentsToJson(this);
}

@JsonSerializable()
class Modules extends Object {
  @JsonKey(name: 'id')
  int id;

  @JsonKey(name: 'url')
  String url;

  @JsonKey(name: 'name')
  String name;

  @JsonKey(name: 'instance')
  int instance;

  @JsonKey(name: 'description')
  String description;

  @JsonKey(name: 'visible')
  int visible;

  @JsonKey(name: 'modicon')
  String modicon;

  @JsonKey(name: 'modname')
  String modname;

  @JsonKey(name: 'modplural')
  String modplural;

  @JsonKey(name: 'indent')
  int indent;

  @JsonKey(name: 'contents')
  late List<Contents> contents;

  Modules({
    this.id = 0,
    this.url = "",
    this.name = "",
    this.instance = 0,
    this.description = "",
    this.visible = 0,
    this.modicon = "",
    this.modname = "",
    this.modplural = "",
    this.indent = 0,
    List<Contents>? contents,
  }) {
    this.contents = contents ?? [];
  }

  factory Modules.fromJson(Map<String, dynamic> srcJson) =>
      _$ModulesFromJson(srcJson);

  Map<String, dynamic> toJson() => _$ModulesToJson(this);
}

@JsonSerializable()
class Contents extends Object {
  @JsonKey(name: 'type')
  String type;

  @JsonKey(name: 'filename')
  String filename;

  @JsonKey(name: 'filepath')
  String filepath;

  @JsonKey(name: 'filesize')
  int filesize;

  @JsonKey(name: 'fileurl')
  String fileurl;

  @JsonKey(name: 'mimetype')
  String mimetype;

  @JsonKey(name: 'timecreated')
  int timecreated;

  @JsonKey(name: 'timemodified')
  int timemodified;

  @JsonKey(name: 'sortorder')
  int sortorder;

  @JsonKey(name: 'userid')
  int userid;

  @JsonKey(name: 'author')
  String author;

  @JsonKey(name: 'license')
  String license;

  Contents({
    this.type = "",
    this.filename = "",
    this.filepath = "",
    this.filesize = 0,
    this.fileurl = "",
    this.mimetype = "",
    this.timecreated = 0,
    this.timemodified = 0,
    this.sortorder = 0,
    this.userid = 0,
    this.author = "",
    this.license = "",
  });

  factory Contents.fromJson(Map<String, dynamic> srcJson) =>
      _$ContentsFromJson(srcJson);

  Map<String, dynamic> toJson() => _$ContentsToJson(this);
}
