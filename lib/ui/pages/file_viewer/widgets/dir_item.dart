import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import 'dir_popup.dart';

class DirectoryItem extends StatelessWidget {
  final FileSystemEntity file;
  final GestureTapCallback tap;
  final PopupMenuItemSelected? popTap;

  const DirectoryItem({
    required this.file,
    required this.tap,
    required this.popTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: tap,
      contentPadding: const EdgeInsets.all(0),
      leading: SizedBox(
        height: 40,
        width: 40,
        child: Center(
          child: Icon(
            Icons.folder_outlined,
            color: Theme.of(context).textTheme.bodyText1!.color,
          ),
        ),
      ),
      title: Text(
        basename(file.path),
        style: const TextStyle(
          fontSize: 14,
        ),
        maxLines: 2,
      ),
      trailing:
          popTap == null ? null : DirPopup(path: file.path, popTap: popTap),
    );
  }
}
