import 'package:flutter_app/src/store/settings_store.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/util/permissions_utils.dart';
import 'package:flutter_app/src/util/my_toast.dart';
import 'package:path_provider/path_provider.dart';

class FileStore {
  static Future<String> findLocalPath(BuildContext context) async {
    bool checkPermission = await PermissionsUtils.isStoragePermission();
    if (!checkPermission) {
      MyToast.show(R.current.noPermission);
      return "";
    }

    Directory? directory =
        await _getFilePath() ?? await getApplicationSupportDirectory();
    return directory.path;
  }

  static Future<String> getDownloadDir(
      BuildContext context, String name) async {
    final basePath = await findLocalPath(context);
    if (basePath.isEmpty) {
      // 沒有儲存權限時 findLocalPath 回 ""（並已提示 noPermission）。不能
      // 照樣接成 '/$name'——那是檔案系統根目錄，create() 必然失敗。
      return "";
    }
    final savedDir = Directory('$basePath/${safeName(name)}');
    // 一定要 await：不然下載可能在目錄還沒建好時就開始寫檔，建立失敗也只是
    // 沒人接的非同步錯誤。recursive 是因為使用者自選的上層目錄也可能不存在；
    // 對已存在的目錄 create(recursive: true) 是 no-op，不必先 exists()。
    await savedDir.create(recursive: true);
    return savedDir.path;
  }

  /// 使用者自選的下載資料夾在公用儲存空間，那裡照 FAT 的規則：名稱帶 `\ / : * ? " < > |` 或控制字元時
  /// 檔案建不出來，App 自己的目錄卻可以，所以換了資料夾才會壞。課名與檔名一律把這些字換成底線。
  static String safeName(String name) => name.replaceAll(_unsafeNameChars, '_');

  static final _unsafeNameChars = RegExp(r'[\x00-\x1f\x7f\\/:*?"<>|]');

  static Future<bool> setFilePath(String? directory) async {
    if (directory == null) return false;
    // 要 await，寫入失敗才不會回報成功。
    await SettingsStore.instance.setDownloadPath(directory);
    return true;
  }

  static Future<Directory?> _getFilePath() async {
    String? path = await SettingsStore.instance.downloadPath;
    if (path != null && path.isNotEmpty) {
      return Directory(path);
    } else {
      return null;
    }
  }
}
