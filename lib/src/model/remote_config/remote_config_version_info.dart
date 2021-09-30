import 'dart:io';

import 'package:json_annotation/json_annotation.dart';

part 'remote_config_version_info.g.dart';

@JsonSerializable()
class RemoteConfigVersionInfo {
  @JsonKey(name: "is_focus_update")
  bool isFocusUpdate;

  @JsonKey(name: "last_version")
  AndroidIosVersionInfo last;

  @JsonKey(name: "last_version_detail")
  String lastVersionDetail;

  @JsonKey(name: "url")
  String url;

  RemoteConfigVersionInfo(
      {required this.last,
      required this.lastVersionDetail,
      required this.isFocusUpdate,
      required this.url});

  factory RemoteConfigVersionInfo.fromJson(Map<String, dynamic> srcJson) =>
      _$RemoteConfigVersionInfoFromJson(srcJson);
}

@JsonSerializable()
class AndroidIosVersionInfo {
  @JsonKey(name: "android")
  String android;

  @JsonKey(name: "ios")
  String ios;

  AndroidIosVersionInfo({required this.android, required this.ios});

  factory AndroidIosVersionInfo.fromJson(Map<String, dynamic> srcJson) =>
      _$AndroidIosVersionInfoFromJson(srcJson);

  String get version {
    return (Platform.isIOS) ? ios : android;
  }
}
