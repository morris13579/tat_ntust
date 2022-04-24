import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_app/src/model/remote_config/remote_config_version_info.dart';

class RemoteConfigUtils {
  static late FirebaseRemoteConfig _remoteConfig;

  static String versionConfigKey = "version_config";
  static String removeADCodeKey = "remove_ad_key";
  static String enableADCodeKey = "ad_enable";

  static Future<void> init() async {
    _remoteConfig = FirebaseRemoteConfig.instance;
    _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(hours: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    /*
    _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: Duration.zero,
        minimumFetchInterval: Duration.zero,
      ),
    );
     */
  }

  static Future<RemoteConfigVersionInfo> getVersionConfig() async {
    await _remoteConfig.fetchAndActivate();
    String result = _remoteConfig.getString(versionConfigKey);
    return RemoteConfigVersionInfo.fromJson(json.decode(result));
  }

  static Future<List<String>> getRemoveADKey() async {
    await _remoteConfig.fetchAndActivate();
    String result = _remoteConfig.getString(removeADCodeKey);
    return (json.decode(result)["key"] as List)
        .map((e) => e.toString())
        .toList();
  }

  static Future<bool> getADEnable() async {
    await _remoteConfig.fetchAndActivate();
    String result = _remoteConfig.getString(enableADCodeKey);
    return (json.decode(result)["value"] as bool);
  }

  static Future<int> getADInterval() async {
    await _remoteConfig.fetchAndActivate();
    String result = _remoteConfig.getString(enableADCodeKey);
    return (json.decode(result)["interval"] as int);
  }
}
