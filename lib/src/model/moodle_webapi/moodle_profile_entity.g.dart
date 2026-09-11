// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moodle_profile_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoodleProfileEntity _$MoodleProfileEntityFromJson(Map<String, dynamic> json) =>
    MoodleProfileEntity(
      sitename: json['sitename'] as String? ?? '',
      username: json['username'] as String? ?? '',
      firstname: json['firstname'] as String? ?? '',
      lastname: json['lastname'] as String? ?? '',
      fullname: json['fullname'] as String? ?? '',
      lang: json['lang'] as String? ?? '',
      userid: (json['userid'] as num?)?.toInt() ?? 0,
      siteurl: json['siteurl'] as String? ?? '',
      userpictureurl: json['userpictureurl'] as String? ?? '',
      functions: (json['functions'] as List<dynamic>?)
              ?.map((e) =>
                  MoodleProfileFunctions.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      downloadfiles: (json['downloadfiles'] as num?)?.toInt() ?? 0,
      uploadfiles: (json['uploadfiles'] as num?)?.toInt() ?? 0,
      release: json['release'] as String? ?? '',
      version: json['version'] as String? ?? '',
      mobilecssurl: json['mobilecssurl'] as String? ?? '',
      advancedfeatures: (json['advancedfeatures'] as List<dynamic>?)
              ?.map((e) => MoodleProfileAdvancedfeatures.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
      usercanmanageownfiles: json['usercanmanageownfiles'] as bool? ?? false,
      userquota: (json['userquota'] as num?)?.toInt() ?? 0,
      usermaxuploadfilesize:
          (json['usermaxuploadfilesize'] as num?)?.toInt() ?? 0,
      userhomepage: (json['userhomepage'] as num?)?.toInt() ?? 0,
      userprivateaccesskey: json['userprivateaccesskey'] as String? ?? '',
      siteid: (json['siteid'] as num?)?.toInt() ?? 0,
      sitecalendartype: json['sitecalendartype'] as String? ?? '',
      usercalendartype: json['usercalendartype'] as String? ?? '',
      userissiteadmin: json['userissiteadmin'] as bool? ?? false,
      theme: json['theme'] as String? ?? '',
      limitconcurrentlogins:
          (json['limitconcurrentlogins'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MoodleProfileEntityToJson(
        MoodleProfileEntity instance) =>
    <String, dynamic>{
      'sitename': instance.sitename,
      'username': instance.username,
      'firstname': instance.firstname,
      'lastname': instance.lastname,
      'fullname': instance.fullname,
      'lang': instance.lang,
      'userid': instance.userid,
      'siteurl': instance.siteurl,
      'userpictureurl': instance.userpictureurl,
      'functions': instance.functions.map((e) => e.toJson()).toList(),
      'downloadfiles': instance.downloadfiles,
      'uploadfiles': instance.uploadfiles,
      'release': instance.release,
      'version': instance.version,
      'mobilecssurl': instance.mobilecssurl,
      'advancedfeatures':
          instance.advancedfeatures.map((e) => e.toJson()).toList(),
      'usercanmanageownfiles': instance.usercanmanageownfiles,
      'userquota': instance.userquota,
      'usermaxuploadfilesize': instance.usermaxuploadfilesize,
      'userhomepage': instance.userhomepage,
      'userprivateaccesskey': instance.userprivateaccesskey,
      'siteid': instance.siteid,
      'sitecalendartype': instance.sitecalendartype,
      'usercalendartype': instance.usercalendartype,
      'userissiteadmin': instance.userissiteadmin,
      'theme': instance.theme,
      'limitconcurrentlogins': instance.limitconcurrentlogins,
    };

MoodleProfileFunctions _$MoodleProfileFunctionsFromJson(
        Map<String, dynamic> json) =>
    MoodleProfileFunctions(
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
    );

Map<String, dynamic> _$MoodleProfileFunctionsToJson(
        MoodleProfileFunctions instance) =>
    <String, dynamic>{
      'name': instance.name,
      'version': instance.version,
    };

MoodleProfileAdvancedfeatures _$MoodleProfileAdvancedfeaturesFromJson(
        Map<String, dynamic> json) =>
    MoodleProfileAdvancedfeatures(
      name: json['name'] as String? ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MoodleProfileAdvancedfeaturesToJson(
        MoodleProfileAdvancedfeatures instance) =>
    <String, dynamic>{
      'name': instance.name,
      'value': instance.value,
    };
