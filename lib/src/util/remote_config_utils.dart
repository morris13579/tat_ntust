import 'package:flutter_app/src/store/credentials_store.dart';
import 'package:flutter_app/src/store/settings_store.dart';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/model/announcement/announcement_json.dart';

/// resolveAnnouncement 的結果：要顯示的公告內容與倒數秒數。
class AnnouncementRequest {
  final List<AnnouncementInfoJson> info;
  final int countDown;

  const AnnouncementRequest(this.info, this.countDown);
}

class RemoteConfigUtils {
  static late FirebaseRemoteConfig _remoteConfig;

  static String announcementKey = "announcement";

  static Future<void> init({focusUpdate = false}) async {
    _remoteConfig = FirebaseRemoteConfig.instance;
    if (kDebugMode || focusUpdate) {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: Duration.zero,
          minimumFetchInterval: Duration.zero,
        ),
      );
    } else {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(hours: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
    }
  }

  static Future<List<AnnouncementInfoJson>> getAnnouncement(
      bool test, bool allTime) async {
    await _remoteConfig.fetchAndActivate();
    String result = _remoteConfig.getString(announcementKey);
    final DateTime lastRead = await SettingsStore.instance.announcementLastRead;
    DateTime now = DateTime.now();
    now = now.toUtc().add(const Duration(hours: 8));
    List<AnnouncementInfoJson> info = [];
    Log.d("Announcement last read: $lastRead");
    for (var i in AnnouncementJson.fromJson(json.decode(result)).list) {
      i.startTime = DateTime.utc(
          i.startTime.year,
          i.startTime.month,
          i.startTime.day,
          i.startTime.hour,
          i.startTime.minute,
          i.startTime.second);
      i.endTime = DateTime.utc(
        i.endTime.year,
        i.endTime.month,
        i.endTime.day,
        i.endTime.hour,
        i.endTime.minute,
        i.endTime.second,
      );
      if (test) {
        info.add(i);
      } else {
        if (!i.test) {
          //開始時間比現在時間晚(代表尚未開始)
          if (i.startTime.isAfter(now)) {
            Log.d("${i.title} not start");
            continue;
          }
          //結束時間比現在時間早(代表結束了)
          if (i.endTime.isBefore(now)) {
            Log.d("${i.title} already end");
            continue;
          }
          if (allTime) {
            info.add(i);
            continue;
          }
          //開始時間比讀時間早(代表讀過)
          if (i.startTime.isBefore(lastRead)) {
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

  static Future<void> setAnnouncementRead() =>
      SettingsStore.instance.markAnnouncementRead();

  /// 解析出啟動彈窗該顯示的公告；沒有要顯示時回 null。看過的也要列出來時
  /// 直接呼叫 [getAnnouncement]（`allTime: true`，見 AppNoticeRepository）。
  ///
  /// 導航交給呼叫端（見 RouteUtils.showAnnouncement），這一層才不需要
  /// import lib/ui。
  static Future<AnnouncementRequest?> resolveAnnouncement(
      {bool test = false}) async {
    final info = await getAnnouncement(test, false);
    if (info.isEmpty) return null;
    // 不走 AuthSession.instance.isSignedIn（判準完全相同，isSignedIn 就是
    // 轉呼這一行）：util 在 tool/deps.py 裡排在 auth 下面，util -> auth 是
    // 上行邊，util -> store 才是下行的。
    if (!CredentialsStore.instance.hasCredentials && !test) {
      Log.d("show announcement close dialog close by no login");
      return null;
    }
    return AnnouncementRequest(info, await getAnnouncementCountTime());
  }
}
