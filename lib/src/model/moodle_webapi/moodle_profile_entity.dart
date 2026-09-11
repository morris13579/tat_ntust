import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'moodle_profile_entity.g.dart';

/// core_webservice_get_site_info 的回應。
///
/// 每個欄位都標了 [JsonKey.defaultValue]，欄位缺席或轉型失敗就退回預設值，
/// 避免 Moodle 換版時少一個欄位就整包解析失敗。
@JsonSerializable(explicitToJson: true)
class MoodleProfileEntity {
  @JsonKey(defaultValue: '')
  String sitename;
  @JsonKey(defaultValue: '')
  String username;
  @JsonKey(defaultValue: '')
  String firstname;
  @JsonKey(defaultValue: '')
  String lastname;
  @JsonKey(defaultValue: '')
  String fullname;
  @JsonKey(defaultValue: '')
  String lang;
  @JsonKey(defaultValue: 0)
  int userid;
  @JsonKey(defaultValue: '')
  String siteurl;
  @JsonKey(defaultValue: '')
  String userpictureurl;
  @JsonKey(defaultValue: [])
  List<MoodleProfileFunctions> functions;
  @JsonKey(defaultValue: 0)
  int downloadfiles;
  @JsonKey(defaultValue: 0)
  int uploadfiles;
  @JsonKey(defaultValue: '')
  String release;
  @JsonKey(defaultValue: '')
  String version;
  @JsonKey(defaultValue: '')
  String mobilecssurl;
  @JsonKey(defaultValue: [])
  List<MoodleProfileAdvancedfeatures> advancedfeatures;
  @JsonKey(defaultValue: false)
  bool usercanmanageownfiles;
  @JsonKey(defaultValue: 0)
  int userquota;
  @JsonKey(defaultValue: 0)
  int usermaxuploadfilesize;
  @JsonKey(defaultValue: 0)
  int userhomepage;
  @JsonKey(defaultValue: '')
  String userprivateaccesskey;
  @JsonKey(defaultValue: 0)
  int siteid;
  @JsonKey(defaultValue: '')
  String sitecalendartype;
  @JsonKey(defaultValue: '')
  String usercalendartype;
  @JsonKey(defaultValue: false)
  bool userissiteadmin;
  @JsonKey(defaultValue: '')
  String theme;
  @JsonKey(defaultValue: 0)
  int limitconcurrentlogins;

  MoodleProfileEntity({
    this.sitename = '',
    this.username = '',
    this.firstname = '',
    this.lastname = '',
    this.fullname = '',
    this.lang = '',
    this.userid = 0,
    this.siteurl = '',
    this.userpictureurl = '',
    this.functions = const [],
    this.downloadfiles = 0,
    this.uploadfiles = 0,
    this.release = '',
    this.version = '',
    this.mobilecssurl = '',
    this.advancedfeatures = const [],
    this.usercanmanageownfiles = false,
    this.userquota = 0,
    this.usermaxuploadfilesize = 0,
    this.userhomepage = 0,
    this.userprivateaccesskey = '',
    this.siteid = 0,
    this.sitecalendartype = '',
    this.usercalendartype = '',
    this.userissiteadmin = false,
    this.theme = '',
    this.limitconcurrentlogins = 0,
  });

  factory MoodleProfileEntity.fromJson(Map<String, dynamic> json) =>
      _$MoodleProfileEntityFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleProfileEntityToJson(this);

  /// [functions] 的 name -> version 索引。私有欄位，json_serializable 不會序列化。
  ///
  /// [functions] 是可變欄位，所以一併記住建索引時用的那個 List 實例；
  /// 欄位被換成另一個 List 時重建，避免索引和資料不同步。
  /// （就地 mutate 同一個 List 偵測不到。）
  Map<String, String>? _wsIndex;
  List<MoodleProfileFunctions>? _wsIndexSource;

  Map<String, String> get _functionIndex {
    if (_wsIndex == null || !identical(_wsIndexSource, functions)) {
      _wsIndexSource = functions;
      _wsIndex = {
        // name 是空字串代表 Moodle 沒送 name（fromJson 退回預設值），
        // 這種項目沒有任何 function 叫得動，別讓 wsAvailable('') 誤判成 true。
        for (final f in functions)
          if (f.name.isNotEmpty) f.name: f.version,
      };
    }
    return _wsIndex!;
  }

  /// 這個 token 在這個站台上能不能呼叫名為 [name] 的 web service function。
  ///
  /// site_info 的 functions[] 就是站台回報給這個 token 的可用清單。呼叫前先
  /// 問這裡，就不必等 HTTP 失敗才發現站台停用了某個 function。
  bool wsAvailable(String name) => _functionIndex.containsKey(name);

  /// 這份 profile 到底知不知道站台開了哪些 function。
  ///
  /// [functions] 每個欄位都有 [JsonKey.defaultValue]，站台少送 functions、
  /// 或者根本解析到一包不是 site_info 的東西時，得到的是空清單而不是例外。
  /// 空清單的意思是「不知道」，不是「站台什麼都沒開」——
  /// `MoodleWebApiConnector.wsFunctionBlocked` 靠這個區分，才不會在資料還沒
  /// 載入時把每一個功能都擋掉。
  bool get knowsWsFunctions => _functionIndex.isNotEmpty;

  /// [name] 這個 function 的版本字串（Moodle 的 YYYYMMDDxx）；站台沒提供時回 null。
  /// 用來擋掉舊站台上參數不相容的新版 function。
  String? wsVersion(String name) => _functionIndex[name];

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable()
class MoodleProfileFunctions {
  @JsonKey(defaultValue: '')
  String name;
  @JsonKey(defaultValue: '')
  String version;

  MoodleProfileFunctions({this.name = '', this.version = ''});

  factory MoodleProfileFunctions.fromJson(Map<String, dynamic> json) =>
      _$MoodleProfileFunctionsFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleProfileFunctionsToJson(this);

  @override
  String toString() => jsonEncode(this);
}

@JsonSerializable()
class MoodleProfileAdvancedfeatures {
  @JsonKey(defaultValue: '')
  String name;
  @JsonKey(defaultValue: 0)
  int value;

  MoodleProfileAdvancedfeatures({this.name = '', this.value = 0});

  factory MoodleProfileAdvancedfeatures.fromJson(Map<String, dynamic> json) =>
      _$MoodleProfileAdvancedfeaturesFromJson(json);

  Map<String, dynamic> toJson() => _$MoodleProfileAdvancedfeaturesToJson(this);

  @override
  String toString() => jsonEncode(this);
}
