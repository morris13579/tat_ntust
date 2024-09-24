import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/util/permissions_utils.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileStore {
  static String storeKey = "download_path";

  static Future<String> findLocalPath(BuildContext context) async {
    bool checkPermission = await PermissionsUtils.isStoragePermission();
    if (!checkPermission) {
      MyToast.show(R.current.noPermission);
      return "";
    }
    Directory? directory = await _getFilePath();
    directory ??= Get.theme.platform == TargetPlatform.android
        ? await getExternalStorageDirectory()
        : await getApplicationSupportDirectory();
    return directory!.path;
  }

  static Future<String> getDownloadDir(
      BuildContext context, String name) async {
    var localPath = '${await findLocalPath(context)}/$name';
    final savedDir = Directory(localPath);
    bool hasExisted = await savedDir.exists();
    if (!hasExisted) {
      savedDir.create();
    }
    return savedDir.path;
  }

  static Future<bool> setFilePath(String? directory) async {
    if (directory != null) {
      SharedPreferences pref = await SharedPreferences.getInstance();
      pref.setString(storeKey, directory);
      return true;
    } else {
      return false;
    }
  }

  static Future<Directory?> _getFilePath() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    String? path = pref.getString(storeKey);
    if (path != null && path.isNotEmpty) {
      return Directory(path);
    } else {
      return null;
    }
  }
}
