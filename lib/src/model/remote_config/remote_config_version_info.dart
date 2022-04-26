import 'dart:io';

import 'package:flutter_app/src/version/update/app_update.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:version/version.dart';

part 'remote_config_version_info.g.dart';

@JsonSerializable()
class RemoteConfigVersionInfo {
  @JsonKey(name: "is_focus_update")
  bool focusUpdate;

  @JsonKey(name: "last_version")
  AndroidIosVersionInfo last;

  @JsonKey(name: "focus_update_version")
  AndroidIosVersionInfo focusUpdateVersion;

  @JsonKey(name: "last_version_detail")
  String lastVersionDetail;

  @JsonKey(name: "link")
  AndroidIosVersionInfo link;

  String get url {
    return (Platform.isAndroid) ? link.android : link.ios;
  }

  String get version {
    return (Platform.isIOS) ? last.ios : last.android;
  }

  String get focusVersion {
    return (Platform.isIOS)
        ? focusUpdateVersion.ios
        : focusUpdateVersion.android;
  }

  Future<bool> get isFocusUpdate async {
    String appInfo = await AppUpdate.getAppVersion();
    return focusUpdate
        ? Version.parse(focusVersion) >= Version.parse(appInfo)
        : false;
  }

  RemoteConfigVersionInfo({
    required this.last,
    required this.lastVersionDetail,
    required this.focusUpdate,
    required this.link,
    required this.focusUpdateVersion,
  });

  factory RemoteConfigVersionInfo.fromJson(Map<String, dynamic> srcJson) =>
      _$RemoteConfigVersionInfoFromJson(srcJson);

  Map<String, dynamic> toJson() => _$RemoteConfigVersionInfoToJson(this);
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

  Map<String, dynamic> toJson() => _$AndroidIosVersionInfoToJson(this);
}
