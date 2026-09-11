import 'package:url_launcher/url_launcher.dart';

class OpenUtils {
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
