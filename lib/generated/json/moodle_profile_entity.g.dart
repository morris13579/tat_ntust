import 'package:flutter_app/generated/json/base/json_convert_content.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';

MoodleProfileEntity $MoodleProfileEntityFromJson(Map<String, dynamic> json) {
  final MoodleProfileEntity moodleProfileEntity = MoodleProfileEntity();
  final String? sitename = jsonConvert.convert<String>(json['sitename']);
  if (sitename != null) {
    moodleProfileEntity.sitename = sitename;
  }
  final String? username = jsonConvert.convert<String>(json['username']);
  if (username != null) {
    moodleProfileEntity.username = username;
  }
  final String? firstname = jsonConvert.convert<String>(json['firstname']);
  if (firstname != null) {
    moodleProfileEntity.firstname = firstname;
  }
  final String? lastname = jsonConvert.convert<String>(json['lastname']);
  if (lastname != null) {
    moodleProfileEntity.lastname = lastname;
  }
  final String? fullname = jsonConvert.convert<String>(json['fullname']);
  if (fullname != null) {
    moodleProfileEntity.fullname = fullname;
  }
  final String? lang = jsonConvert.convert<String>(json['lang']);
  if (lang != null) {
    moodleProfileEntity.lang = lang;
  }
  final int? userid = jsonConvert.convert<int>(json['userid']);
  if (userid != null) {
    moodleProfileEntity.userid = userid;
  }
  final String? siteurl = jsonConvert.convert<String>(json['siteurl']);
  if (siteurl != null) {
    moodleProfileEntity.siteurl = siteurl;
  }
  final String? userpictureurl = jsonConvert.convert<String>(
      json['userpictureurl']);
  if (userpictureurl != null) {
    moodleProfileEntity.userpictureurl = userpictureurl;
  }
  final List<MoodleProfileFunctions>? functions = (json['functions'] as List<
      dynamic>?)
      ?.map(
          (e) =>
      jsonConvert.convert<MoodleProfileFunctions>(e) as MoodleProfileFunctions)
      .toList();
  if (functions != null) {
    moodleProfileEntity.functions = functions;
  }
  final int? downloadfiles = jsonConvert.convert<int>(json['downloadfiles']);
  if (downloadfiles != null) {
    moodleProfileEntity.downloadfiles = downloadfiles;
  }
  final int? uploadfiles = jsonConvert.convert<int>(json['uploadfiles']);
  if (uploadfiles != null) {
    moodleProfileEntity.uploadfiles = uploadfiles;
  }
  final String? release = jsonConvert.convert<String>(json['release']);
  if (release != null) {
    moodleProfileEntity.release = release;
  }
  final String? version = jsonConvert.convert<String>(json['version']);
  if (version != null) {
    moodleProfileEntity.version = version;
  }
  final String? mobilecssurl = jsonConvert.convert<String>(
      json['mobilecssurl']);
  if (mobilecssurl != null) {
    moodleProfileEntity.mobilecssurl = mobilecssurl;
  }
  final List<
      MoodleProfileAdvancedfeatures>? advancedfeatures = (json['advancedfeatures'] as List<
      dynamic>?)?.map(
          (e) =>
      jsonConvert.convert<MoodleProfileAdvancedfeatures>(
          e) as MoodleProfileAdvancedfeatures).toList();
  if (advancedfeatures != null) {
    moodleProfileEntity.advancedfeatures = advancedfeatures;
  }
  final bool? usercanmanageownfiles = jsonConvert.convert<bool>(
      json['usercanmanageownfiles']);
  if (usercanmanageownfiles != null) {
    moodleProfileEntity.usercanmanageownfiles = usercanmanageownfiles;
  }
  final int? userquota = jsonConvert.convert<int>(json['userquota']);
  if (userquota != null) {
    moodleProfileEntity.userquota = userquota;
  }
  final int? usermaxuploadfilesize = jsonConvert.convert<int>(
      json['usermaxuploadfilesize']);
  if (usermaxuploadfilesize != null) {
    moodleProfileEntity.usermaxuploadfilesize = usermaxuploadfilesize;
  }
  final int? userhomepage = jsonConvert.convert<int>(json['userhomepage']);
  if (userhomepage != null) {
    moodleProfileEntity.userhomepage = userhomepage;
  }
  final String? userprivateaccesskey = jsonConvert.convert<String>(
      json['userprivateaccesskey']);
  if (userprivateaccesskey != null) {
    moodleProfileEntity.userprivateaccesskey = userprivateaccesskey;
  }
  final int? siteid = jsonConvert.convert<int>(json['siteid']);
  if (siteid != null) {
    moodleProfileEntity.siteid = siteid;
  }
  final String? sitecalendartype = jsonConvert.convert<String>(
      json['sitecalendartype']);
  if (sitecalendartype != null) {
    moodleProfileEntity.sitecalendartype = sitecalendartype;
  }
  final String? usercalendartype = jsonConvert.convert<String>(
      json['usercalendartype']);
  if (usercalendartype != null) {
    moodleProfileEntity.usercalendartype = usercalendartype;
  }
  final bool? userissiteadmin = jsonConvert.convert<bool>(
      json['userissiteadmin']);
  if (userissiteadmin != null) {
    moodleProfileEntity.userissiteadmin = userissiteadmin;
  }
  final String? theme = jsonConvert.convert<String>(json['theme']);
  if (theme != null) {
    moodleProfileEntity.theme = theme;
  }
  final int? limitconcurrentlogins = jsonConvert.convert<int>(
      json['limitconcurrentlogins']);
  if (limitconcurrentlogins != null) {
    moodleProfileEntity.limitconcurrentlogins = limitconcurrentlogins;
  }
  return moodleProfileEntity;
}

Map<String, dynamic> $MoodleProfileEntityToJson(MoodleProfileEntity entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['sitename'] = entity.sitename;
  data['username'] = entity.username;
  data['firstname'] = entity.firstname;
  data['lastname'] = entity.lastname;
  data['fullname'] = entity.fullname;
  data['lang'] = entity.lang;
  data['userid'] = entity.userid;
  data['siteurl'] = entity.siteurl;
  data['userpictureurl'] = entity.userpictureurl;
  data['functions'] = entity.functions.map((v) => v.toJson()).toList();
  data['downloadfiles'] = entity.downloadfiles;
  data['uploadfiles'] = entity.uploadfiles;
  data['release'] = entity.release;
  data['version'] = entity.version;
  data['mobilecssurl'] = entity.mobilecssurl;
  data['advancedfeatures'] =
      entity.advancedfeatures.map((v) => v.toJson()).toList();
  data['usercanmanageownfiles'] = entity.usercanmanageownfiles;
  data['userquota'] = entity.userquota;
  data['usermaxuploadfilesize'] = entity.usermaxuploadfilesize;
  data['userhomepage'] = entity.userhomepage;
  data['userprivateaccesskey'] = entity.userprivateaccesskey;
  data['siteid'] = entity.siteid;
  data['sitecalendartype'] = entity.sitecalendartype;
  data['usercalendartype'] = entity.usercalendartype;
  data['userissiteadmin'] = entity.userissiteadmin;
  data['theme'] = entity.theme;
  data['limitconcurrentlogins'] = entity.limitconcurrentlogins;
  return data;
}

extension MoodleProfileEntityExtension on MoodleProfileEntity {
  MoodleProfileEntity copyWith({
    String? sitename,
    String? username,
    String? firstname,
    String? lastname,
    String? fullname,
    String? lang,
    int? userid,
    String? siteurl,
    String? userpictureurl,
    List<MoodleProfileFunctions>? functions,
    int? downloadfiles,
    int? uploadfiles,
    String? release,
    String? version,
    String? mobilecssurl,
    List<MoodleProfileAdvancedfeatures>? advancedfeatures,
    bool? usercanmanageownfiles,
    int? userquota,
    int? usermaxuploadfilesize,
    int? userhomepage,
    String? userprivateaccesskey,
    int? siteid,
    String? sitecalendartype,
    String? usercalendartype,
    bool? userissiteadmin,
    String? theme,
    int? limitconcurrentlogins,
  }) {
    return MoodleProfileEntity()
      ..sitename = sitename ?? this.sitename
      ..username = username ?? this.username
      ..firstname = firstname ?? this.firstname
      ..lastname = lastname ?? this.lastname
      ..fullname = fullname ?? this.fullname
      ..lang = lang ?? this.lang
      ..userid = userid ?? this.userid
      ..siteurl = siteurl ?? this.siteurl
      ..userpictureurl = userpictureurl ?? this.userpictureurl
      ..functions = functions ?? this.functions
      ..downloadfiles = downloadfiles ?? this.downloadfiles
      ..uploadfiles = uploadfiles ?? this.uploadfiles
      ..release = release ?? this.release
      ..version = version ?? this.version
      ..mobilecssurl = mobilecssurl ?? this.mobilecssurl
      ..advancedfeatures = advancedfeatures ?? this.advancedfeatures
      ..usercanmanageownfiles = usercanmanageownfiles ??
          this.usercanmanageownfiles
      ..userquota = userquota ?? this.userquota
      ..usermaxuploadfilesize = usermaxuploadfilesize ??
          this.usermaxuploadfilesize
      ..userhomepage = userhomepage ?? this.userhomepage
      ..userprivateaccesskey = userprivateaccesskey ?? this.userprivateaccesskey
      ..siteid = siteid ?? this.siteid
      ..sitecalendartype = sitecalendartype ?? this.sitecalendartype
      ..usercalendartype = usercalendartype ?? this.usercalendartype
      ..userissiteadmin = userissiteadmin ?? this.userissiteadmin
      ..theme = theme ?? this.theme
      ..limitconcurrentlogins = limitconcurrentlogins ??
          this.limitconcurrentlogins;
  }
}

MoodleProfileFunctions $MoodleProfileFunctionsFromJson(
    Map<String, dynamic> json) {
  final MoodleProfileFunctions moodleProfileFunctions = MoodleProfileFunctions();
  final String? name = jsonConvert.convert<String>(json['name']);
  if (name != null) {
    moodleProfileFunctions.name = name;
  }
  final String? version = jsonConvert.convert<String>(json['version']);
  if (version != null) {
    moodleProfileFunctions.version = version;
  }
  return moodleProfileFunctions;
}

Map<String, dynamic> $MoodleProfileFunctionsToJson(
    MoodleProfileFunctions entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['name'] = entity.name;
  data['version'] = entity.version;
  return data;
}

extension MoodleProfileFunctionsExtension on MoodleProfileFunctions {
  MoodleProfileFunctions copyWith({
    String? name,
    String? version,
  }) {
    return MoodleProfileFunctions()
      ..name = name ?? this.name
      ..version = version ?? this.version;
  }
}

MoodleProfileAdvancedfeatures $MoodleProfileAdvancedfeaturesFromJson(
    Map<String, dynamic> json) {
  final MoodleProfileAdvancedfeatures moodleProfileAdvancedfeatures = MoodleProfileAdvancedfeatures();
  final String? name = jsonConvert.convert<String>(json['name']);
  if (name != null) {
    moodleProfileAdvancedfeatures.name = name;
  }
  final int? value = jsonConvert.convert<int>(json['value']);
  if (value != null) {
    moodleProfileAdvancedfeatures.value = value;
  }
  return moodleProfileAdvancedfeatures;
}

Map<String, dynamic> $MoodleProfileAdvancedfeaturesToJson(
    MoodleProfileAdvancedfeatures entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['name'] = entity.name;
  data['value'] = entity.value;
  return data;
}

extension MoodleProfileAdvancedfeaturesExtension on MoodleProfileAdvancedfeatures {
  MoodleProfileAdvancedfeatures copyWith({
    String? name,
    int? value,
  }) {
    return MoodleProfileAdvancedfeatures()
      ..name = name ?? this.name
      ..value = value ?? this.value;
  }
}