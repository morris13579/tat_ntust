import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';
import 'package:flutter_app/src/model/remote_config/remote_config_version_info.dart';
import 'package:flutter_app/ui/pages/announcement/announcement_page.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteConfigUtils {
  static late FirebaseRemoteConfig _remoteConfig;

  static String versionConfigKey = "version_config";
  static String removeADCodeKey = "remove_ad_key";
  static String enableADCodeKey = "ad_enable";
  static String announcementKey = "announcement";
  static String announcementLastReadTimeKey = "announcement_last_read_time";

  static Future<void> init({focusUpdate = false}) async {
    _remoteConfig = FirebaseRemoteConfig.instance;
    if (kDebugMode || focusUpdate) {
      _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: Duration.zero,
          minimumFetchInterval: Duration.zero,
        ),
      );
    } else {
      _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(hours: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
    }
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

  static Future<List<AnnouncementInfoJson>> getAnnouncement(
      bool test, bool allTime) async {
    await _remoteConfig.fetchAndActivate();
    String result = _remoteConfig.getString(announcementKey);
    var pref = await SharedPreferences.getInstance();
    DateTime lastRead = DateTime.parse(
        pref.getString(announcementLastReadTimeKey) ??
            DateTime.utc(2000).toString());
    DateTime now = DateTime.now();
    now = now.toUtc().add(const Duration(hours: 8));
    List<AnnouncementInfoJson> info = [];
    Log.d("Announcement last read: $lastRead");
    for (var i in AnnouncementJson.fromJson(json.decode(result)).list) {
      if (test) {
        info.add(i);
      } else {
        if (!i.test) {
          if (allTime) {
            info.add(i);
            continue;
          }
          //開始時間比現在時間晚(代表尚未開始)
          if (i.startTime.compareTo(now) > 0) {
            Log.d("${i.title} not start");
            continue;
          }
          //結束時間比現在時間早(代表結束了)
          if (i.endTime.compareTo(now) < 0) {
            Log.d("${i.title} already end");
            continue;
          }
          //開始時間比讀時間早(代表讀過)
          if (i.startTime.compareTo(lastRead) < 0) {
            Log.d("${i.title} already read");
            continue;
          }
          info.add(i);
        }
      }
    }
    return info;
  }

  static Future<int> getAnnouncementCountTime() async {
    await _remoteConfig.fetchAndActivate();
    String result = _remoteConfig.getString(announcementKey);
    return AnnouncementJson.fromJson(json.decode(result)).countDown;
  }

  static Future<void> setAnnouncementRead() async {
    var pref = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    now = now.toUtc().add(const Duration(hours: 8));
    pref.setString(announcementLastReadTimeKey, now.toString());
  }

  static Future<void> showAnnouncementDialog(
      {bool test = false, allTime = false}) async {
    List<AnnouncementInfoJson> info = await getAnnouncement(test, allTime);
    if (info.isNotEmpty) {
      await Get.dialog<bool>(
        AnnouncementPage(
          info: info,
          countDown: await getAnnouncementCountTime(),
        ),
        barrierDismissible: false, // user must tap button!
      );
    }
  }
}
