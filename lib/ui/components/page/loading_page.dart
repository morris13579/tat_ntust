import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_utils/src/platform/platform.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage(
      {super.key,
      required this.isLoading,
      this.isShowBackground = true,
      this.message});

  final bool isLoading;
  final bool isShowBackground;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Visibility(
        visible: isLoading,
        child: Stack(
          children: [
            Positioned.fill(
                child: Container(
                    color:
                        Colors.black.withOpacity(isShowBackground ? 0.4 : 0))),
            Center(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                indicator(),
                Visibility(
                    visible: message != null,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(message ?? ""),
                    )),
              ],
            ))
          ],
        ));
  }

  Widget indicator() {
    if (GetPlatform.isIOS) {
      return const CupertinoActivityIndicator();
    } else {
      return const CircularProgressIndicator(
          strokeCap: StrokeCap.round, strokeWidth: 4.5);
    }
  }
}
