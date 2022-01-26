import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/model/remote_config/remote_config_version_info.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/src/version/update/app_update.dart';
import 'package:version/version.dart';

class APPVersion {
  static Future<void> initAndCheck() async {
    RemoteConfigVersionInfo config = await RemoteConfigUtils.getVersionConfig();
    if (!config.isFocusUpdate) {
      if (!Model.instance.autoCheckAppUpdate ||
          !await Model.instance.getFirstUse(Model.appCheckUpdate) ||
          Model.instance.getAccount().isEmpty) return;
    }
    Model.instance.setAlreadyUse(Model.appCheckUpdate);
    await check();
    await checkIFAPPUpdate(); //檢查是否有更新
  }

  static Future<bool> check() async {
    Log.d("Start check update");
    bool value = await AppUpdate.checkUpdate();
    return value;
  }

  static Future<void> checkIFAPPUpdate() async {
    //檢查是否有更新APP
    String version = await AppUpdate.getAppVersion();
    String preVersion = await Model.instance.getVersion();
    Log.d(" preVersion: $preVersion \n version: $version");
    await Model.instance.setVersion(version);
    if (preVersion != version) {
      await updateVersionCallback(preVersion);
    }
  }

  static Future<void> updateVersionCallback(String preVersion) async {
    //更新版本後會執行函數
    //用途資料更新...
    Version version;
    try {
      version = Version.parse(preVersion);
    } catch (e) {
      return;
    }
    Model.instance.getOtherSetting().useMoodleWebApi = true;
    await Model.instance.saveSetting();
    if (version < Version.parse("1.2.3")) {
      await Model.instance.clearCourseSetting();
      await Model.instance.saveCourseSetting();
    }
  }
}
