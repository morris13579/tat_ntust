import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:get/get.dart';

class CourseSearchBar extends StatelessWidget {
  const CourseSearchBar(
      {super.key,
      this.controller,
      this.onChange,
      this.readOnly = false,
      this.onTap,
      this.isBack = false, this.onSubmit});

  final TextEditingController? controller;
  final bool isBack;
  final bool readOnly;
  final Function()? onTap;
  final Function(String)? onSubmit;
  final Function(String)? onChange;

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      color: Get.theme.colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              searchButton(),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  readOnly: readOnly,
                  onTap: onTap,
                  onSubmitted: onSubmit,
                  style: const TextStyle(height: 1),
                  decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: R.current.search),
                  onChanged: onChange,
                ),
              )
            ],
          )),
    );
  }

  Widget searchButton() {
    var icon = Icon(
      CupertinoIcons.search,
      color: Get.theme.colorScheme.onSurface,
    );

    if (isBack) {
      icon = Icon(
        Icons.arrow_back_ios_new,
        size: 18,
        color: Get.theme.colorScheme.onSurface,
      );
    }

    return CupertinoButton(
        padding: EdgeInsets.zero,
        minSize: 0.0,
        onPressed: () {
          Get.back();
        },
        child: icon);
  }
}
