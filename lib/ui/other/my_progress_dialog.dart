import 'dart:math';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'custom_progress_dialog.dart';

const double kitSize = 20;
const kitColor = Colors.blue;
final kits = <Widget>[
  const SpinKitRotatingCircle(size: kitSize, color: kitColor),
  const SpinKitRotatingPlain(size: kitSize, color: kitColor),
  const SpinKitChasingDots(size: kitSize + 5, color: kitColor),
  const SpinKitPulse(size: kitSize, color: kitColor),
  const SpinKitDoubleBounce(size: kitSize, color: kitColor),
  const SpinKitWave(
      size: kitSize, color: kitColor, type: SpinKitWaveType.start),
  const SpinKitThreeBounce(size: kitSize, color: kitColor),
  const SpinKitThreeInOut(size: kitSize, color: kitColor),
  const SpinKitWanderingCubes(size: kitSize, color: kitColor),
  const SpinKitCircle(size: kitSize + 5, color: kitColor),
  const SpinKitFadingFour(size: kitSize + 5, color: kitColor),
  const SpinKitFadingCube(size: kitSize, color: kitColor),
  const SpinKitCubeGrid(size: kitSize, color: kitColor),
  const SpinKitFoldingCube(size: kitSize, color: kitColor),
  const SpinKitRing(size: kitSize, color: kitColor),
  const SpinKitDualRing(size: kitSize, color: kitColor),
  const SpinKitSpinningLines(size: kitSize, color: kitColor),
  const SpinKitFadingGrid(size: kitSize, color: kitColor),
  const SpinKitSquareCircle(size: kitSize, color: kitColor),
  const SpinKitSpinningCircle(size: kitSize, color: kitColor),
  const SpinKitFadingCircle(size: kitSize + 5, color: kitColor),
  const SpinKitHourGlass(size: kitSize, color: kitColor),
  const SpinKitPouringHourGlass(size: kitSize + 10, color: kitColor),
  const SpinKitRipple(size: kitSize, color: kitColor),
];

class MyProgressDialog {
  static void showProgressDialogOld(
      BuildContext context, String message) async {}

  static void progressDialog(String message) async {
    BotToast.showCustomLoading(toastBuilder: (cancel) {
      return dialog(message);
    });
  }

  static Widget dialog(String message) {
    final int number = Random().nextInt(kits.length);
    return CustomProgressDialog(
      child: Container(
        decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.all(Radius.circular(5))),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 60,
              width: 100,
              child: kits[number],
            ),
            message == null
                ? Padding(
                    padding: EdgeInsets.all(0),
                  )
                : Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      message,
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
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
