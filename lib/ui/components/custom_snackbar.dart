import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomSnackBar {
  static showCustomSnackBar(
      {required String title, String message = "", Duration? duration}) {
    Get.snackbar(
      title.isEmpty ? "" : title,
      message.isEmpty ? "" : message,
      messageText: message.isEmpty ? const SizedBox() : null,
      duration: duration ?? const Duration(seconds: 3),
      margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
      padding: const EdgeInsets.only(left: 18, top: 16, bottom: 16, right: 16),
      colorText: Colors.white,
      backgroundColor: Colors.green,
      icon: const Icon(
        Icons.check_circle,
        color: Colors.white,
      ),
    );
  }

  static showCustomErrorSnackBar(
      {required String title,
      required String message,
      Color? color,
      Duration? duration}) {
    Get.snackbar(
      title.isEmpty ? "Error" : title,
      message.isEmpty ? "error.someError".tr : message,
      duration: duration ?? const Duration(seconds: 3),
      margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
      padding: const EdgeInsets.only(left: 18, top: 16, bottom: 16, right: 16),
      colorText: Colors.white,
      backgroundColor: color ?? Colors.redAccent,
      icon: const Icon(
        Icons.error,
        color: Colors.white,
      ),
    );
  }

  static showCustomToast(
      {String? title,
      required String message,
      Color? color,
      Duration? duration}) {
    Get.rawSnackbar(
      title: title,
      duration: duration ?? const Duration(seconds: 3),
      snackStyle: SnackStyle.GROUNDED,
      backgroundColor: color ?? Colors.green,
      onTap: (snack) {
        Get.closeAllSnackbars();
      },
      //overlayBlur: 0.8,
      message: message,
    );
  }

  static showCustomErrorToast(
      {String? title,
      required String message,
      Color? color,
      Duration? duration}) {
    Get.rawSnackbar(
      title: title,
      duration: duration ?? const Duration(seconds: 3),
      snackStyle: SnackStyle.GROUNDED,
      backgroundColor: color ?? Colors.redAccent,
      onTap: (snack) {
        Get.closeAllSnackbars();
      },
      //overlayBlur: 0.8,
      message: message,
    );
  }

  static void showErrorDialog(String errorMsg, Function() onPressed) {
    if (Get.context == null) {
      return;
    }

    if (GetPlatform.isIOS) {
      showCupertinoDialog(
          context: Get.context!,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text("error.someError".tr),
              content: Text(errorMsg),
              actions: [
                CupertinoDialogAction(
                    isDefaultAction: true,
                    onPressed: onPressed,
                    child: Text(
                      "OK",
                      style: TextStyle(color: Get.theme.primaryColor),
                    ))
              ],
            );
          });
      return;
    }

    showDialog(
        context: Get.context!,
        builder: (context) {
          return AlertDialog(
            title: Text("error.someError".tr),
            content: Text(
              errorMsg,
              style:
                  const TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
            ),
            actions: [
              TextButton(
                  onPressed: onPressed,
                  child: Text(
                    "OK".tr,
                    style: TextStyle(color: Get.theme.primaryColor),
                  ))
            ],
          );
        });
  }
}
