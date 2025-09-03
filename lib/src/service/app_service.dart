import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:get/get.dart';
import 'package:flutter_app/src/ad/ad_manager.dart';
import 'package:flutter_app/src/file/my_downloader.dart';
import 'package:flutter_app/src/notifications/notifications.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/src/version/app_version.dart';


class AppService extends GetxService {
  Future<void> init() async {
    await _checkAgreeContributor();
    await _appInit();
    await _checkAppVersion();
  }

  Future<void> _appInit() async {
    var context = Get.context;
    if (context == null) {
      throw Exception("BuildContext is null");
    }

    try {
      await LanguageUtils.init(context);
      await RemoteConfigUtils.init();
      await AdManager.init();
      await MyDownloader.init();
      await Notifications.instance.init();
      Log.init();
      Get.forceAppUpdate();
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
    }
  }

  Future<void> _checkAgreeContributor() async {
    if (!(await Model.instance.getAgreeContributor())) {
      await RouteUtils.toAgreePrivacyPolicyScreen();
    }
  }

  Future<void> _checkAppVersion() async {
    final isNeedUpdate = await APPVersion.initAndCheck();
    if (!isNeedUpdate) {
      RemoteConfigUtils.showAnnouncementDialog();
    }
  }
}