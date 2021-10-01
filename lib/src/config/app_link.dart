import 'dart:io';

class AppLink {
  static const androidAppPackageName = "club.ntust.tat";
  static const _playStore =
      "https://play.google.com/store/apps/details?id=$androidAppPackageName";
  static const _appleStore = "https://apps.apple.com/tw/app/id1513875597";
  static const githubOwner = "morris13579";
  static const githubName = "tat_ntust";
  static const gitHub = "https://github.com/$githubOwner/$githubName";
  static const feedbackBaseUrl =
      "https://docs.google.com/forms/d/e/1FAIpQLSfHdgBnYpc7plIH2GBYeYcStwPIgZRB_oKL3guMXWX87svryA/viewform";

  static const privacyPolicyUrl =
      "https://raw.githubusercontent.com/$githubOwner/$githubName/master/privacy-policy.md";

  static String feedback(String mainVersion, String log) {
    Uri url = Uri.https(
        Uri.parse(feedbackBaseUrl).host, Uri.parse(feedbackBaseUrl).path, {
      "entry.201642894": (Platform.isAndroid) ? "Android" : "IOS",
      "entry.1614642121": mainVersion,
      "entry.991226144": log
    });
    return url.toString();
  }

  static String get storeLink {
    return (Platform.isAndroid) ? _playStore : _appleStore;
  }
}
