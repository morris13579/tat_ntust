import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_app/debug/log/Log.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdManager {
  static const String androidAppID = "ca-app-pub-7649352174867436~2995231487";
  static const String iosAppID = "ca-app-pub-7649352174867436~3290345570";
  static const String androidInterstitialAdUnitId =
      "ca-app-pub-7649352174867436/5625619479";

  static const String iosInterstitialAdUnitId =
      "ca-app-pub-7649352174867436/1098957193";

  static const String testInterstitialAdUnitId =
      "ca-app-pub-3940256099942544/1033173712";

  static const bool inTest = kDebugMode;

  static InterstitialAd? _interstitialAd;

  static Future<void> init() async {
    await MobileAds.instance.initialize();
    await _createInterstitialAd();
    Log.d("AD run in ${(inTest) ? "Debug" : "Release"} mode");
  }

  static Future<void> _createInterstitialAd() async {
    await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
          },
          onAdFailedToLoad: (LoadAdError error) {
            _interstitialAd = null;
            Log.e("AD load fail $error");
          },
        ));
  }

  static final String _adPrefKey = "ad_key";

  static Future<void> setADEnable(bool value) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    await pref.setBool(_adPrefKey, value);
  }

  static Future<bool> getADEnable() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getBool("ad_key") ?? true;
  }

  static Future<void> showDownloadAD() async {
    if (!await RemoteConfigUtils.getADEnable()) {
      Log.d("AD is disable by remote config");
      return;
    }
    if (!await getADEnable()) {
      Log.d("AD is disable by valid code");
      return;
    }
    int intervalTime = await RemoteConfigUtils.getADInterval();
    Log.d("AD interval time is $intervalTime sec");
    if (!await Model.instance
        .getFirstUse("ad_download", timeOut: intervalTime)) {
      Log.d("AD is disable by interval");
      return;
    }
    if (_interstitialAd != null) {
      _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          Log.d('ad onAdShowedFullScreenContent.');
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          Log.d('$ad onAdDismissedFullScreenContent.');
          ad.dispose();
          _createInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          Log.e('$ad onAdFailedToShowFullScreenContent: $error');
          ad.dispose();
          _createInterstitialAd();
        },
      );
      _interstitialAd?.show();
    } else {
      Log.d("_interstitialAd is null");
      _createInterstitialAd();
    }
  }

  static String get appId {
    if (Platform.isAndroid) {
      return androidAppID;
    } else if (Platform.isIOS) {
      return iosAppID;
    } else {
      throw new UnsupportedError("Unsupported platform");
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return (inTest) ? testInterstitialAdUnitId : androidInterstitialAdUnitId;
    } else if (Platform.isIOS) {
      return iosInterstitialAdUnitId;
    } else {
      throw new UnsupportedError("Unsupported platform");
    }
  }
}
