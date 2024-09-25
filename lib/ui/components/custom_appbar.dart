import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

AppBar mainAppbar(
    {String title = "",
      List<Widget>? action,
      bool isShowBack = false,
      PreferredSizeWidget? bottom,
      BuildContext? context}) {
  return AppBar(
    actions: action,
    centerTitle: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: !isShowBack ? const SizedBox(width: 0,) : null,
    leadingWidth: !isShowBack ? 0 : null,
    bottom: bottom,
    title: Text(title),
  );
}

AppBar baseAppbar(
    {String title = "",
    List<Widget>? action,
    BuildContext? context,
    PreferredSizeWidget? bottom,
    Color? backgroundColor}) {
  return AppBar(
    leading: IconButton(
      splashColor: Colors.transparent,
      splashRadius: 18,
      icon: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Get.iconColor,
            ),
      onPressed: () {
        Get.back();
      },
    ),
    actions: action,
    centerTitle: false,
    backgroundColor: Get.theme.appBarTheme.backgroundColor,
    elevation: 0,
    bottom: bottom,
    title: Text(title),
  );
}

AppBar searchAppBar(
    {String findHint = "",
    List<Widget>? action,
    Function(String)? onInputChange,
    Function()? onClose}) {
  return AppBar(
    centerTitle: false,
    backgroundColor: Get.theme.scaffoldBackgroundColor,
    elevation: 0,
    leading: const SizedBox(),
    leadingWidth: 0,
    title: TextField(
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: findHint,
      ),
      style: const TextStyle(height: 1),
      cursorRadius: const Radius.circular(999),
      onChanged: onInputChange,
    ),
    actions: [
      Container(
        margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
        height: kToolbarHeight,
        width: 1.8,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.grey.shade400),
      ),
      ...action ?? [],
      IconButton(
        onPressed: onClose,
        icon: const Icon(CupertinoIcons.xmark_circle),
        tooltip: "gameTool.findInWeb".tr,
      )
    ],
  );
}
