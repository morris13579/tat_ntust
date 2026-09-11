import 'dart:async';

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:get/get.dart';
import 'package:flutter_app/src/service/notifications.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/src/version/app_version.dart';

class AppService extends GetxService {
  /// 是否還沒同意隱私政策。導航交給呼叫端（main.dart），
  /// 這一層不 import lib/ui。
  Future<bool> get needsPrivacyAgreement async =>
      !(await Model.instance.getAgreeContributor());

  Future<void> init() async {
    await _appInit();
    try {
      await APPVersion.migrateIfUpdated();
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
    }
  }

  Future<void> _appInit() async {
    var context = Get.context;
    if (context == null) {
      throw Exception("BuildContext is null");
    }

    try {
      await LanguageUtils.init(context);
      await RemoteConfigUtils.init();
      await Notifications.instance.init();
      Log.init();
      unawaited(Get.forceAppUpdate());
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
    }
  }
}
