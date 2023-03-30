import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/util/file_utils.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import 'file_icon.dart';
import 'file_popup.dart';

class FileItem extends StatelessWidget {
  final FileSystemEntity? file;
  final PopupMenuItemSelected? popTap;

  const FileItem({
    required this.file,
    this.popTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => OpenFilex.open(file!.path),
      contentPadding: const EdgeInsets.all(0),
      leading: SizedBox(
        height: 40,
        width: 40,
        child: Center(
          child: FileIcon(
            file: file,
          ),
        ),
      ),
      title: Text(
        p.basename(file!.path),
        style: const TextStyle(
          fontSize: 14,
        ),
        maxLines: 2,
      ),
      subtitle: Text(
        "${FileUtils.formatBytes(file == null ? 678476 : File(file!.path).lengthSync(), 2)},"
        " ${file == null ? "Test" : FileUtils.formatTime(File(file!.path).lastModifiedSync().toIso8601String())}",
      ),
      trailing: popTap == null
          ? null
          : FilePopup(
              path: file!.path,
              popTap: popTap,
            ),
    );
  }
}
