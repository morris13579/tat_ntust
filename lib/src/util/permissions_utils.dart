import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsUtils {
  static Future<bool> isStoragePermission() async {
    // 先對所在平台進行判斷
    if (Get.theme.platform == TargetPlatform.android) {
      var deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      var apiVersion = androidInfo.version.sdkInt;
      if(apiVersion >= 33) {
        return true;
      }

      Permission permission = Permission.storage;
      var status = await permission.status;

      if(status == PermissionStatus.granted) {
        return true;
      }

      Map<Permission, PermissionStatus> permissions = await [
        permission
      ].request();

      if (permissions[permission] == PermissionStatus.granted) {
        return true;
      }
    } else if(Get.theme.platform == TargetPlatform.iOS) {
      return true;
    }

    return false;
  }

  static Future<bool> isNotificationPermission() async {
    // 先對所在平台進行判斷
    if (Get.theme.platform == TargetPlatform.android) {
      Permission permission = Permission.notification;
      var status = await permission.status;

      if(status == PermissionStatus.granted) {
        return true;
      }

      Map<Permission, PermissionStatus> permissions = await [
        permission
      ].request();

      if (permissions[permission] == PermissionStatus.granted) {
        return true;
      }
    } else if(Get.theme.platform == TargetPlatform.iOS) {
      return true;
    }

    return false;
  }
}
