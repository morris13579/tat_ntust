/// id : 450596
/// name : "一般"
/// visible : 1
/// summary : ""
/// summaryformat : 1
/// modules : [{"id":392288,"url":"https://moodle.ntust.edu.tw/mod/forum/view.php?id=392288","name":"公佈欄 Bulletin Board","instance":57664,"description":"<div class=\"no-overflow\"><img src=\"https://moodle.ntust.edu.tw/pluginfile.php/826652/mod_label/intro/message_outline.png\" alt=\"\" width=\"26\" height=\"26\" style=\"vertical-align:text-bottom;margin:0 .5em;\" class=\"img-responsive\" /><a href=\"http://moodle.ntust.edu.tw/user/index.php?roleid=3&amp;&amp;id=28914\" target=\"_blank\" rel=\"noreferrer\"> 送訊息連絡老師</a><sup></sup><a href=\"http://moodle.ntust.edu.tw/mod/forum/discuss.php?d=1798#p2260\" target=\"_blank\" rel=\"noreferrer\"><sup>(操作說明)</sup></a></div>","visible":1,"modicon":"https://moodle.ntust.edu.tw/theme/image.php/essential/forum/1631171023/icon","modname":"forum","modplural":"討論區","indent":0,"contents":[{"type":"file","filename":"VLSIout21f.pdf","filepath":"/","filesize":118837,"fileurl":"https://moodle.ntust.edu.tw/webservice/pluginfile.php/843265/mod_resource/content/1/VLSIout21f.pdf?forcedownload=1","timecreated":1629592425,"timemodified":1629592428,"sortorder":1,"userid":5252,"author":"老師@ 林銘波","license":"allrightsreserved"}]},null]
import 'package:json_annotation/json_annotation.dart';

part 'moodle_core_course_get_contents.g.dart';

/// id : 450596
/// name : "一般"
/// visible : 1
/// summary : ""
/// summaryformat : 1
/// modules : [{"id":392288,"url":"https://moodle.ntust.edu.tw/mod/forum/view.php?id=392288","name":"公佈欄 Bulletin Board","instance":57664,"description":"<div class=\"no-overflow\"><img src=\"https://moodle.ntust.edu.tw/pluginfile.php/826652/mod_label/intro/message_outline.png\" alt=\"\" width=\"26\" height=\"26\" style=\"vertical-align:text-bottom;margin:0 .5em;\" class=\"img-responsive\" /><a href=\"http://moodle.ntust.edu.tw/user/index.php?roleid=3&amp;&amp;id=28914\" target=\"_blank\" rel=\"noreferrer\"> 送訊息連絡老師</a><sup></sup><a href=\"http://moodle.ntust.edu.tw/mod/forum/discuss.php?d=1798#p2260\" target=\"_blank\" rel=\"noreferrer\"><sup>(操作說明)</sup></a></div>","visible":1,"modicon":"https://moodle.ntust.edu.tw/theme/image.php/essential/forum/1631171023/icon","modname":"forum","modplural":"討論區","indent":0,"contents":[{"type":"file","filename":"VLSIout21f.pdf","filepath":"/","filesize":118837,"fileurl":"https://moodle.ntust.edu.tw/webservice/pluginfile.php/843265/mod_resource/content/1/VLSIout21f.pdf?forcedownload=1","timecreated":1629592425,"timemodified":1629592428,"sortorder":1,"userid":5252,"author":"老師@ 林銘波","license":"allrightsreserved"}]},null]

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

/// type : "file"
/// filename : "VLSIout21f.pdf"
/// filepath : "/"
/// filesize : 118837
/// fileurl : "https://moodle.ntust.edu.tw/webservice/pluginfile.php/843265/mod_resource/content/1/VLSIout21f.pdf?forcedownload=1"
/// timecreated : 1629592425
/// timemodified : 1629592428
/// sortorder : 1
/// userid : 5252
/// author : "老師@ 林銘波"
/// license : "allrightsreserved"
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
