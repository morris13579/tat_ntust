/// id : 450596
/// name : "一般"
/// visible : 1
/// summary : ""
/// summaryformat : 1
/// modules : [{"id":392288,"url":"https://moodle.ntust.edu.tw/mod/forum/view.php?id=392288","name":"公佈欄 Bulletin Board","instance":57664,"description":"<div class=\"no-overflow\"><img src=\"https://moodle.ntust.edu.tw/pluginfile.php/826652/mod_label/intro/message_outline.png\" alt=\"\" width=\"26\" height=\"26\" style=\"vertical-align:text-bottom;margin:0 .5em;\" class=\"img-responsive\" /><a href=\"http://moodle.ntust.edu.tw/user/index.php?roleid=3&amp;&amp;id=28914\" target=\"_blank\" rel=\"noreferrer\"> 送訊息連絡老師</a><sup></sup><a href=\"http://moodle.ntust.edu.tw/mod/forum/discuss.php?d=1798#p2260\" target=\"_blank\" rel=\"noreferrer\"><sup>(操作說明)</sup></a></div>","visible":1,"modicon":"https://moodle.ntust.edu.tw/theme/image.php/essential/forum/1631171023/icon","modname":"forum","modplural":"討論區","indent":0,"contents":[{"type":"file","filename":"VLSIout21f.pdf","filepath":"/","filesize":118837,"fileurl":"https://moodle.ntust.edu.tw/webservice/pluginfile.php/843265/mod_resource/content/1/VLSIout21f.pdf?forcedownload=1","timecreated":1629592425,"timemodified":1629592428,"sortorder":1,"userid":5252,"author":"老師@ 林銘波","license":"allrightsreserved"}]},null]

class MoodleCoreCourseGetContents {
  int _id;
  String _name;
  int _visible;
  String _summary;
  int _summaryformat;
  List<Modules> _modules;

  int get id => _id;
  String get name => _name;
  int get visible => _visible;
  String get summary => _summary;
  int get summaryformat => _summaryformat;
  List<Modules> get modules => _modules;

  MoodleCoreCourseGetContents({
      int id, 
      String name, 
      int visible, 
      String summary, 
      int summaryformat, 
      List<Modules> modules}){
    _id = id;
    _name = name;
    _visible = visible;
    _summary = summary;
    _summaryformat = summaryformat;
    _modules = modules;
}

  MoodleCoreCourseGetContents.fromJson(dynamic json) {
    _id = json['id'];
    _name = json['name'];
    _visible = json['visible'];
    _summary = json['summary'];
    _summaryformat = json['summaryformat'];
    if (json['modules'] != null) {
      _modules = [];
      json['modules'].forEach((v) {
        _modules.add(Modules.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map['id'] = _id;
    map['name'] = _name;
    map['visible'] = _visible;
    map['summary'] = _summary;
    map['summaryformat'] = _summaryformat;
    if (_modules != null) {
      map['modules'] = _modules.map((v) => v.toJson()).toList();
    }
    return map;
  }

}

/// id : 392288
/// url : "https://moodle.ntust.edu.tw/mod/forum/view.php?id=392288"
/// name : "公佈欄 Bulletin Board"
/// instance : 57664
/// description : "<div class=\"no-overflow\"><img src=\"https://moodle.ntust.edu.tw/pluginfile.php/826652/mod_label/intro/message_outline.png\" alt=\"\" width=\"26\" height=\"26\" style=\"vertical-align:text-bottom;margin:0 .5em;\" class=\"img-responsive\" /><a href=\"http://moodle.ntust.edu.tw/user/index.php?roleid=3&amp;&amp;id=28914\" target=\"_blank\" rel=\"noreferrer\"> 送訊息連絡老師</a><sup></sup><a href=\"http://moodle.ntust.edu.tw/mod/forum/discuss.php?d=1798#p2260\" target=\"_blank\" rel=\"noreferrer\"><sup>(操作說明)</sup></a></div>"
/// visible : 1
/// modicon : "https://moodle.ntust.edu.tw/theme/image.php/essential/forum/1631171023/icon"
/// modname : "forum"
/// modplural : "討論區"
/// indent : 0
/// contents : [{"type":"file","filename":"VLSIout21f.pdf","filepath":"/","filesize":118837,"fileurl":"https://moodle.ntust.edu.tw/webservice/pluginfile.php/843265/mod_resource/content/1/VLSIout21f.pdf?forcedownload=1","timecreated":1629592425,"timemodified":1629592428,"sortorder":1,"userid":5252,"author":"老師@ 林銘波","license":"allrightsreserved"}]

class Modules {
  int _id;
  String _url;
  String _name;
  int _instance;
  String _description;
  int _visible;
  String _modicon;
  String _modname;
  String _modplural;
  int _indent;
  List<Contents> _contents;

  int get id => _id;
  String get url => _url;
  String get name => _name;
  int get instance => _instance;
  String get description => _description;
  int get visible => _visible;
  String get modicon => _modicon;
  String get modname => _modname;
  String get modplural => _modplural;
  int get indent => _indent;
  List<Contents> get contents => _contents;

  Modules({
      int id, 
      String url, 
      String name, 
      int instance, 
      String description, 
      int visible, 
      String modicon, 
      String modname, 
      String modplural, 
      int indent, 
      List<Contents> contents}){
    _id = id;
    _url = url;
    _name = name;
    _instance = instance;
    _description = description;
    _visible = visible;
    _modicon = modicon;
    _modname = modname;
    _modplural = modplural;
    _indent = indent;
    _contents = contents;
}

  Modules.fromJson(dynamic json) {
    _id = json['id'];
    _url = json['url'];
    _name = json['name'];
    _instance = json['instance'];
    _description = json['description'];
    _visible = json['visible'];
    _modicon = json['modicon'];
    _modname = json['modname'];
    _modplural = json['modplural'];
    _indent = json['indent'];
    if (json['contents'] != null) {
      _contents = [];
      json['contents'].forEach((v) {
        _contents.add(Contents.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map['id'] = _id;
    map['url'] = _url;
    map['name'] = _name;
    map['instance'] = _instance;
    map['description'] = _description;
    map['visible'] = _visible;
    map['modicon'] = _modicon;
    map['modname'] = _modname;
    map['modplural'] = _modplural;
    map['indent'] = _indent;
    if (_contents != null) {
      map['contents'] = _contents.map((v) => v.toJson()).toList();
    }
    return map;
  }

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

class Contents {
  String _type;
  String _filename;
  String _filepath;
  int _filesize;
  String _fileurl;
  int _timecreated;
  int _timemodified;
  int _sortorder;
  int _userid;
  String _author;
  String _license;

  String get type => _type;
  String get filename => _filename;
  String get filepath => _filepath;
  int get filesize => _filesize;
  String get fileurl => _fileurl;
  int get timecreated => _timecreated;
  int get timemodified => _timemodified;
  int get sortorder => _sortorder;
  int get userid => _userid;
  String get author => _author;
  String get license => _license;

  Contents({
      String type, 
      String filename, 
      String filepath, 
      int filesize, 
      String fileurl, 
      int timecreated, 
      int timemodified, 
      int sortorder, 
      int userid, 
      String author, 
      String license}){
    _type = type;
    _filename = filename;
    _filepath = filepath;
    _filesize = filesize;
    _fileurl = fileurl;
    _timecreated = timecreated;
    _timemodified = timemodified;
    _sortorder = sortorder;
    _userid = userid;
    _author = author;
    _license = license;
}

  Contents.fromJson(dynamic json) {
    _type = json['type'];
    _filename = json['filename'];
    _filepath = json['filepath'];
    _filesize = json['filesize'];
    _fileurl = json['fileurl'];
    _timecreated = json['timecreated'];
    _timemodified = json['timemodified'];
    _sortorder = json['sortorder'];
    _userid = json['userid'];
    _author = json['author'];
    _license = json['license'];
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    map['type'] = _type;
    map['filename'] = _filename;
    map['filepath'] = _filepath;
    map['filesize'] = _filesize;
    map['fileurl'] = _fileurl;
    map['timecreated'] = _timecreated;
    map['timemodified'] = _timemodified;
    map['sortorder'] = _sortorder;
    map['userid'] = _userid;
    map['author'] = _author;
    map['license'] = _license;
    return map;
  }

}