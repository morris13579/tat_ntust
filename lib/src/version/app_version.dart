import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';

class APPVersion {
  static Future<String> getAppVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// 版本升級後的資料遷移。
  ///
  /// 版本戳記必須在遷移成功之後才落盤：先寫版本的話，遷移中途失敗下次冷啟動
  /// preVersion == version 就直接跳過，使用者停在半遷移狀態且畫面上零徵兆。
  static Future<void> migrateIfUpdated() async {
    String version = await getAppVersion();
    String preVersion = await Model.instance.getVersion();
    Log.d(" preVersion: $preVersion \n version: $version");
    if (preVersion != version) {
      await updateVersionCallback(preVersion);
    }
    await Model.instance.setVersion(version);
  }

  static Future<void> updateVersionCallback(String preVersion) async {
    Version version;
    try {
      version = Version.parse(preVersion);
    } catch (e) {
      version = Version.parse("0.0.0");
    }
    Model.instance.getOtherSetting().useMoodleWebApi = true;
    await Model.instance.saveSetting();
    if (version < Version.parse("1.2.6")) {
      await Model.instance.clearCourseSetting();
      await Model.instance.saveCourseSetting();
      await Model.instance.clearCourseTableList();
      await Model.instance.saveCourseTableList();
    }
  }
}
