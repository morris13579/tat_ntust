import 'dart:io';

import 'package:flutter_app/debug/log/Log.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdManager {
  static final String androidAppID = "ca-app-pub-7649352174867436~2995231487";
  static final String androidInterstitialAdUnitId =
      "ca-app-pub-7649352174867436/5625619479";
  static InterstitialAd _interstitialAd;

  static Future<void> init() async {
    await MobileAds.instance.initialize();
    await _createInterstitialAd();
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
    if (!await getADEnable()) {
      return;
    }
    if (_interstitialAd != null) {
      _interstitialAd.fullScreenContentCallback = FullScreenContentCallback(
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
      _interstitialAd.show();
    } else {
      _createInterstitialAd();
    }
  }

  static String get appId {
    if (Platform.isAndroid) {
      return androidAppID;
    } else if (Platform.isIOS) {
      return "<YOUR_IOS_ADMOB_APP_ID>";
    } else {
      throw new UnsupportedError("Unsupported platform");
    }
  }

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return "<YOUR_ANDROID_BANNER_AD_UNIT_ID";
    } else if (Platform.isIOS) {
      return "<YOUR_IOS_BANNER_AD_UNIT_ID>";
    } else {
      throw new UnsupportedError("Unsupported platform");
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return androidInterstitialAdUnitId;
    } else if (Platform.isIOS) {
      return "<YOUR_IOS_INTERSTITIAL_AD_UNIT_ID>";
    } else {
      throw new UnsupportedError("Unsupported platform");
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return "<YOUR_ANDROID_REWARDED_AD_UNIT_ID>";
    } else if (Platform.isIOS) {
      return "<YOUR_IOS_REWARDED_AD_UNIT_ID>";
    } else {
      throw new UnsupportedError("Unsupported platform");
    }
  }
}
