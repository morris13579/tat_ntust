import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:url_launcher/url_launcher.dart';

class OpenUtils {
  static String mxPlayerFreePackageName = "com.mxtech.videoplayer.ad";
  static String mxPlayerProPackageName = "com.mxtech.videoplayer.pro";

  static Future<bool> _androidLaunch(String url,
      [String name = "video"]) async {
    AndroidIntent intent;
    intent = AndroidIntent(
      action: 'action_view',
      data: url,
      type: "application/mpegurl",
      arguments: {"title": name},
    );
    try {
      await intent.launch();
    } catch (e) {
      return false;
    }
    return true;
  }

  static Future<bool> _iosLaunch(String url) async {
    try {
      Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      return false;
    }
    return true;
  }

  static Future<bool> launchMXPlayer(
      {required String url, required String name}) async {
    bool open = true;
    if (Platform.isAndroid) {
      open = await _androidLaunch(url, name);
    } else {
      open = await _iosLaunch(url);
    }
    if (!open) {
      MyToast.show(R.current.noSupportExternalVideoPlayer);
    }
    return open;
  }

  static Future<bool> launchURL(String url) async {
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return true;
    } else {
      return false;
    }
  }
}
