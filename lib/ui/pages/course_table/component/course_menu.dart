import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:get/get.dart';

class CourseMenu extends StatelessWidget {
  const CourseMenu({super.key, required this.studentId, required this.onSelected});

  final String studentId;
  final Function(int) onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: 0,
          child: Text(R.current.searchCredit),
        ),
        PopupMenuItem(
          value: 1,
          child: Text(R.current.loadFavorite),
        ),
        if (studentId == Model.instance.getAccount())
          PopupMenuItem(
            value: 2,
            child: Text(R.current.importCourse),
          ),
        if (GetPlatform.isAndroid)
          PopupMenuItem(
            value: 3,
            child: Text(R.current.setAsAndroidWeight),
          ),
      ],
    );
  }
}
