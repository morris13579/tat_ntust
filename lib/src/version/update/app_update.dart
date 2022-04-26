import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_link.dart';
import 'package:flutter_app/src/model/remote_config/remote_config_version_info.dart';
import 'package:flutter_app/src/util/open_utils.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:get/get.dart';
import 'package:package_info/package_info.dart';
import 'package:sprintf/sprintf.dart';
import 'package:version/version.dart';

class AppUpdate {
  static Future<bool> checkUpdate() async {
    try {
      RemoteConfigVersionInfo config =
          await RemoteConfigUtils.getVersionConfig();
      String appInfo = await AppUpdate.getAppVersion();
      Version currentVersion = Version.parse(appInfo);
      Version latestVersion = Version.parse(config.version);
      bool needUpdate = latestVersion > currentVersion;
      if (needUpdate) {
        _showUpdateDialog(config);
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  static Future<String> getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  static void _showUpdateDialog(RemoteConfigVersionInfo value) async {
    String title = sprintf("%s %s", [R.current.findNewVersion, value.version]);
    bool isFocusUpdate = await value.isFocusUpdate;
    await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              if (isFocusUpdate) ...[
                Text(R.current.isFocusUpdate),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                )
              ],
              Text(value.lastVersionDetail),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(R.current.cancel),
            onPressed: () {
              Get.back<bool>(result: false);
            },
          ),
          TextButton(
            child: Text(R.current.update),
            onPressed: () {
              Get.back<bool>(result: true);
              //_openAppStore();
              _openLink(value.url);
            },
          ),
        ],
      ),
      barrierDismissible: false, // user must tap button!
    );
    if (isFocusUpdate) {
      MyToast.show(R.current.appWillClose);
      await Future.delayed(const Duration(seconds: 1));
      SystemNavigator.pop();
      exit(0);
    }
  }

  static void _openLink(String url) async {
    await OpenUtils.launchURL(url);
  }

  static void _openAppStore() async {
    String url = AppLink.storeLink;
    await OpenUtils.launchURL(url);
  }
}
