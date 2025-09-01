import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';
import 'package:get/get.dart';

class MoodleSettingController extends GetxController with GetSingleTickerProviderStateMixin {
  TabController? tabController;

  var settingList = RxList<MoodleSettingPreferencesComponents>();
  var tab = RxList<MoodleSettingPreferencesProcessors>();
  var isError = false.obs;
  var errorMsg = "".obs;
  var isLoading = false.obs;

  @override
  Future<void> onInit() async {
    super.onInit();

    await getSettingData();
  }

  Future<void> getSettingData() async {
    try {
      isLoading.value = true;
      isError.value = false;

      var res = await MoodleWebApiConnector.getSettings();
      settingList.value = res?.preferences.components ?? [];

      tab.value = res?.preferences.processors ?? [];
      tab.sort((a,b) => a.displayname.compareTo(b.displayname));

      tabController = TabController(length: tab.length, vsync: this);
    } catch(e) {
      isError.value = true;
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleSetting(String key, String type, bool checked) async {
    try {
      isLoading.value = true;
      isError.value = false;

      var values = <String>[];

      if(type == "email") {
        if(checked) {
          values.add("email");
        }

        var isAnotherEnabled = settingList.where((e) {
          var setting = e.notifications.firstWhereOrNull((element) => element.preferencekey == key);
          if(setting == null) {
            return false;
          }
          return setting.processors.firstWhere((element) => element.name == "popup").enabled;
        }).isNotEmpty;

        if(isAnotherEnabled) {
          values.add("popup");
        }
      } else if(type == "popup") {
        if(checked) {
          values.add("popup");
        }

        var isAnotherEnabled = settingList.where((e) {
          var setting = e.notifications.firstWhereOrNull((element) => element.preferencekey == key);
          if(setting == null) {
            return false;
          }
          return setting.processors.firstWhere((element) => element.name == "email").enabled;
        }).isNotEmpty;

        if(isAnotherEnabled) {
          values.add("email");
        }
      }

      await MoodleWebApiConnector.toggleSetting(key, values);
      var res = await MoodleWebApiConnector.getSettings();
      settingList.value = res?.preferences.components ?? [];
    } catch(e) {
      isError.value = true;
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}