import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart' as p;

class FileIcon extends StatelessWidget {
  final FileSystemEntity? file;

  const FileIcon({
    required this.file,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    File f = File(file!.path);
    String extension = p.extension(f.path).toLowerCase();
    String? mimeType = mime(p.basename(file!.path).toLowerCase());
    String type = mimeType == null ? "" : mimeType.split("/")[0];
    if (extension == ".apk") {
      return const Icon(
        Icons.android,
        color: Colors.green,
      );
    } else if (extension == ".crdownload") {
      return const Icon(
        Icons.file_download,
        color: Colors.lightBlue,
      );
    } else if (extension == ".zip" || extension.contains("tar")) {
      return const Icon(
        FontAwesome5.file_archive,
        color: Colors.deepOrangeAccent,
      );
    } else if (extension == ".epub" ||
        extension == ".pdf" ||
        extension == ".mobi") {
      return const Icon(
        FontAwesome5.file_alt,
        color: Colors.orangeAccent,
      );
    } else {
      switch (type) {
        case "audio":
          {
            return const Icon(
              FontAwesome5.file_audio,
              color: Colors.blue,
            );
          }
        case "text":
          {
            return const Icon(
              FontAwesome5.file_alt,
              color: Colors.orangeAccent,
            );
          }
        default:
          {
            return Icon(
              FontAwesome5.file,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            );
          }
      }
    }
  }
}
