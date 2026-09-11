import 'dart:io';

class AppLink {
  static const githubOwner = "morris13579";
  static const githubName = "tat_ntust";
  static const gitHub = "https://github.com/$githubOwner/$githubName";
  static const feedbackBaseUrl =
      "https://docs.google.com/forms/d/e/1FAIpQLSfHdgBnYpc7plIH2GBYeYcStwPIgZRB_oKL3guMXWX87svryA/viewform";

  /// 條款的修改紀錄。條款本身是 repo 裡的一個檔案，GitHub 的 commits 頁就是
  /// 它完整的版本歷史。
  static const privacyPolicyHistory =
      "$gitHub/commits/master/privacy-policy.md";

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
}
