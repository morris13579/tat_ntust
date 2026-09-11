import 'package:flutter_app/src/R.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';
import 'package:get/get.dart';

class MoodleSettingController extends GetxController
    with GetSingleTickerProviderStateMixin {
  TabController? tabController;

  /// 每個通知管道（分頁）各自持有一個 ScrollController。
  ///
  /// 不可以整頁共用一顆：TabBarView 在切頁動畫期間會同時掛著前後兩個分頁的
  /// ListView，兩個 ScrollPosition attach 到同一顆之後，任何 `.offset` /
  /// `.jumpTo` 都會踩到 `_positions.single` 的 StateError（release 也照拋）。
  final Map<String, ScrollController> _scrollControllers = {};

  var settingList = RxList<MoodleSettingPreferencesComponents>();
  var tab = RxList<MoodleSettingPreferencesProcessors>();
  var isError = false.obs;
  var errorMsg = "".obs;
  var isLoading = false.obs;

  /// 單一開關正在寫入。
  ///
  /// 刻意不沿用 [isLoading]：isLoading 會讓 BasePage 把整個 ListView 換成
  /// LoadingPage，列表連同捲動位置一起被銷毀，切一個開關就彈回最上面。
  /// 獨立旗標讓列表全程留在畫面上，只把開關暫時停用。
  var isToggling = false.obs;

  /// 取得（必要時建立）某個分頁的 ScrollController。
  ScrollController scrollControllerOf(String type) =>
      _scrollControllers.putIfAbsent(type, ScrollController.new);

  @override
  Future<void> onInit() async {
    super.onInit();

    await getSettingData();
  }

  @override
  void onClose() {
    // tabController 必須在 super.onClose() 之前 dispose：
    // GetSingleTickerProviderStateMixin.onClose 會 assert ticker 已經停止，
    // 而停掉 ticker 的正是 TabController.dispose()。
    tabController?.dispose();
    for (final scrollController in _scrollControllers.values) {
      scrollController.dispose();
    }
    _scrollControllers.clear();
    super.onClose();
  }

  Future<void> getSettingData() async {
    try {
      isLoading.value = true;
      isError.value = false;

      final res = await MoodleWebApiConnector.getSettings();
      if (res == null) {
        // 取不到就是錯誤，不要用 ?? [] 把它畫成「載入完成、你沒有任何設定」。
        isError.value = true;
        errorMsg.value = R.current.somethingError;
        return;
      }
      settingList.value = res.preferences.components;

      // 行動裝置（airnotifier）那一頁不顯示：它管的是 Moodle 官方 App 的推播，
      // 在這個 App 裡打開也收不到，只會讓人以為設定沒生效。
      tab.value = res.preferences.processors
          .where((e) => e.name != 'airnotifier')
          .toList();
      tab.sort((a, b) => a.displayname.compareTo(b.displayname));

      // GetSingleTickerProviderStateMixin 一輩子只發一個 ticker（dispose 之後
      // 也不會還回去），所以 getSettingData 只能走這一次，onInit 是唯一呼叫端。
      // 之後要加「重新整理」的話，得先把 mixin 換成 GetTickerProviderStateMixin，
      // 並在這行之前補 tabController?.dispose()，否則不是撞 ticker 的 assert
      // 就是每 refresh 一次漏一顆 TabController。
      tabController = TabController(length: tab.length, vsync: this);
    } catch (e) {
      isError.value = true;
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleSetting(String key, String type, bool checked) async {
    try {
      isToggling.value = true;
      isError.value = false;

      var values = settingList
          .firstWhere((e) {
            var setting = e.notifications
                .firstWhereOrNull((element) => element.preferencekey == key);
            return setting != null;
          })
          .notifications
          .firstWhere((element) => element.preferencekey == key)
          .processors
          .where((p) => p.enabled)
          .map((p) => p.name)
          .toList();

      if (checked) {
        values.add(type);
      } else {
        values.remove(type);
      }

      final ok = await MoodleWebApiConnector.toggleSetting(key, values);
      if (!ok) {
        // 寫入沒成功就把本地的樂觀更新回滾，否則畫面會顯示一個伺服器上
        // 並不存在的狀態，使用者以為設定好了。
        if (checked) {
          values.remove(type);
        } else {
          values.add(type);
        }
        isError.value = true;
        errorMsg.value = R.current.somethingError;
        return;
      }
      final res = await MoodleWebApiConnector.getSettings();
      if (res != null) {
        settingList.value = res.preferences.components;
      }
    } catch (e) {
      isError.value = true;
      errorMsg.value = e.toString();
    } finally {
      isToggling.value = false;
    }
  }
}
