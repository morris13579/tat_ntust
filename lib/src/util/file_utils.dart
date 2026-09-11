import 'dart:io';
import 'dart:math';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:intl/intl.dart';
import 'package:mime_type/mime_type.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

/// 檔案總管用得到的工具。
class FileUtils {
  static String formatBytes(bytes, decimals) {
    if (bytes == 0) return "0.0 KB";
    var k = 1024,
        dm = decimals <= 0 ? 0 : decimals,
        sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'],
        i = (log(bytes) / log(k)).floor();
    return '${(bytes / pow(k, i)).toStringAsFixed(dm)} ${sizes[i]}';
  }

  static String formatTime(String iso) {
    DateTime date = DateTime.parse(iso);
    DateTime now = DateTime.now();
    DateTime yDay = DateTime.now().subtract(const Duration(days: 1));
    DateTime dateFormat = DateTime.parse(
        "${date.year}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}T00:00:00.000Z");
    DateTime today = DateTime.parse(
        "${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}T00:00:00.000Z");
    DateTime yesterday = DateTime.parse(
        "${yDay.year}-${yDay.month.toString().padLeft(2, "0")}-${yDay.day.toString().padLeft(2, "0")}T00:00:00.000Z");

    if (dateFormat == today) {
      return "Today ${DateFormat("HH:mm").format(DateTime.parse(iso))}";
    } else if (dateFormat == yesterday) {
      return "Yesterday ${DateFormat("HH:mm").format(DateTime.parse(iso))}";
    } else {
      return DateFormat("MMM dd, HH:mm").format(DateTime.parse(iso));
    }
  }

  static List<FileSystemEntity> sortList(
      List<FileSystemEntity> list, int sort) {
    switch (sort) {
      case 0:
        if (list.toString().contains("Directory")) {
          list.sort((f1, f2) => p
              .basename(f1.path)
              .toLowerCase()
              .compareTo(p.basename(f2.path).toLowerCase()));
          return list
            ..sort((f1, f2) => f1
                .toString()
                .split(":")[0]
                .toLowerCase()
                .compareTo(f2.toString().split(":")[0].toLowerCase()));
        } else {
          return list
            ..sort((f1, f2) => p
                .basename(f1.path)
                .toLowerCase()
                .compareTo(p.basename(f2.path).toLowerCase()));
        }

      case 1:
        list.sort((f1, f2) => p
            .basename(f1.path)
            .toLowerCase()
            .compareTo(p.basename(f2.path).toLowerCase()));
        if (list.toString().contains("Directory")) {
          list.sort((f1, f2) => f1
              .toString()
              .split(":")[0]
              .toLowerCase()
              .compareTo(f2.toString().split(":")[0].toLowerCase()));
        }
        return list.reversed.toList();

      case 2:
        return list
          ..sort((f1, f2) => FileSystemEntity.isFileSync(f1.path) &&
                  FileSystemEntity.isFileSync(f2.path)
              ? File(f1.path)
                  .lastModifiedSync()
                  .compareTo(File(f2.path).lastModifiedSync())
              : 1);

      case 3:
        list.sort((f1, f2) => FileSystemEntity.isFileSync(f1.path) &&
                FileSystemEntity.isFileSync(f2.path)
            ? File(f1.path)
                .lastModifiedSync()
                .compareTo(File(f2.path).lastModifiedSync())
            : 1);
        return list.reversed.toList();

      case 4:
        list.sort((f1, f2) => FileSystemEntity.isFileSync(f1.path) &&
                FileSystemEntity.isFileSync(f2.path)
            ? File(f1.path).lengthSync().compareTo(File(f2.path).lengthSync())
            : 0);
        return list.reversed.toList();

      case 5:
        return list
          ..sort((f1, f2) => FileSystemEntity.isFileSync(f1.path) &&
                  FileSystemEntity.isFileSync(f2.path)
              ? File(f1.path).lengthSync().compareTo(File(f2.path).lengthSync())
              : 0);

      default:
        return list..sort();
    }
  }

  static Future<void> openFile(String path) async {
    final originFile = File(path);
    if (!await originFile.exists()) {
      throw Exception("File not found");
    }

    if (Platform.isAndroid) {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String packageName = packageInfo.packageName;
      String fileName = path.split("/").last;
      String contentUri =
          "content://$packageName.fileProvider/internal_files/$fileName";

      final intent = AndroidIntent(
        action: 'action_view',
        data: contentUri,
        type: mime(fileName),
        flags: <int>[
          Flag.FLAG_GRANT_READ_URI_PERMISSION,
          Flag.FLAG_ACTIVITY_NEW_TASK,
        ],
      );

      await intent.launch();
      return;
    }

    await OpenFilex.open(originFile.path);
  }
}
