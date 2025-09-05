import 'dart:math';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

import 'custom_progress_dialog.dart';

const double kitSize = 20;
final kits = <Widget>[
  SpinKitRotatingCircle(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitChasingDots(size: kitSize + 5, color: Get.theme.colorScheme.primary),
  SpinKitPulse(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitDoubleBounce(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitThreeBounce(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitThreeInOut(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitCircle(size: kitSize + 5, color: Get.theme.colorScheme.primary),
  SpinKitFadingFour(size: kitSize + 5, color: Get.theme.colorScheme.primary),
  SpinKitRing(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitDualRing(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitSpinningLines(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitFadingGrid(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitSquareCircle(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitSpinningCircle(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitFadingCircle(size: kitSize + 5, color: Get.theme.colorScheme.primary),
  SpinKitHourGlass(size: kitSize, color: Get.theme.colorScheme.primary),
  SpinKitPouringHourGlass(size: kitSize + 10, color: Get.theme.colorScheme.primary),
  SpinKitRipple(size: kitSize, color: Get.theme.colorScheme.primary),
];

class MyProgressDialog {
  static void progressDialog(String? message) async {
    BotToast.showCustomLoading(toastBuilder: (cancel) {
      return dialog(message);
    });
  }

  static Widget dialog(String? message) {
    final int number = Random().nextInt(kits.length);
    return CustomProgressDialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 60,
              width: 100,
              child: kits[10],
            ),
            Visibility(
              visible: message != null,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  "$message",
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> hideProgressDialog() async {
    BotToast.cleanAll();
  }

  static Future<void> hideAllDialog() async {
    BotToast.cleanAll();
  }
}
