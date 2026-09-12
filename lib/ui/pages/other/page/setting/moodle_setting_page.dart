import 'package:flutter/material.dart';
import 'package:flutter_app/ui/components/tat_switch.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/setting/moodle_setting_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';
import 'package:flutter_app/src/util/ui_utils.dart';
import 'package:flutter_app/ui/components/page/base_page.dart';
import 'package:flutter_app/ui/components/tat_tab_bar.dart';
import 'package:flutter_app/ui/other/theme_context.dart';
import 'package:get/get.dart';

class MoodleSettingPage extends GetView<MoodleSettingController> {
  const MoodleSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    // build() 每次重建都會跑，所以要先問過再 put：少了這個判斷，每次 rebuild
    // 都會 new 一顆 MoodleSettingController（連同 ScrollController），GetX 看到
    // key 已存在又把它丟掉，白造一份沒人 dispose 的垃圾。
    if (!Get.isRegistered<MoodleSettingController>()) {
      Get.put(MoodleSettingController());
    }

    return Obx(() {
      // 一定要在 Obx 的 builder 裡讀 isToggling：寫入結束後就是靠這個訂閱觸發
      // 重建，把重抓回來的 settingList 畫上去。ListView 的 itemBuilder 在別的
      // element 裡跑，在那裡讀 .value 不會被這個 Obx 訂閱到。
      final isToggling = controller.isToggling.value;

      return BasePage(
        title: R.current.moodle_setting,
        isLoading: controller.isLoading.value,
        isError: controller.isError.value,
        errorMsg: controller.errorMsg.value,
        isSubPage: true,
        // 清單自己吃安全區：交給 BasePage 的話最後一列會停在安全區上緣，
        // 底下空一條跟頁面同色的死帶，看起來像被切掉。
        bottomSafeArea: false,
        // 這一頁沒有 DefaultTabController 可以回退，tabController 還沒建好時
        // 不能先把分頁列畫出來。
        bottom: controller.tabController == null
            ? null
            : TatTabBar(
                controller: controller.tabController,
                tabs: controller.tab
                    .map((e) => Tab(text: e.displayname))
                    .toList(),
              ),
        child: TabBarView(
            controller: controller.tabController,
            children: controller.tab
                .map((element) =>
                    _buildSettingList(context, element.name, isToggling))
                .toList()),
      );
    });
  }

  Widget _buildSettingList(BuildContext context, String type, bool isToggling) {
    return ListView.separated(
        // 每個分頁一顆 ScrollController：切頁動畫期間兩個分頁的 ListView 會
        // 同時存在，共用一顆會讓它同時掛兩個 position。
        controller: controller.scrollControllerOf(type),
        padding: EdgeInsets.fromLTRB(
            12, 12, 12, 12 + MediaQuery.paddingOf(context).bottom),
        itemBuilder: (context, index) {
          var item = controller.settingList[index];
          return _buildSettingItem(context, item, type, isToggling);
        },
        separatorBuilder: (context, index) {
          return const SizedBox(height: 14);
        },
        itemCount: controller.settingList.length);
  }

  Widget _buildSettingItem(
      BuildContext context,
      MoodleSettingPreferencesComponents components,
      String type,
      bool isToggling) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8),
          child: Text(
            components.displayname,
            style: context.text.titleSmall
                ?.copyWith(color: context.scheme.onSurface),
          ),
        ),
        ListView.separated(
          itemBuilder: (context, index) {
            final e = components.notifications[index];
            final borderRadius =
                UIUtils.getBorderRadius(index, components.notifications.length);

            return Container(
                decoration: BoxDecoration(
                    color: context.tokens.card, borderRadius: borderRadius),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.displayname,
                        style: context.text.bodyLarge
                            ?.copyWith(color: context.scheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    TatSwitch(
                      value: e.processors
                          .where((element) =>
                              element.name == type && element.enabled)
                          .isNotEmpty,
                      // 寫入期間停用所有開關。toggleSetting 是「讀目前 enabled
                      // 清單 → 送整份清單 → 重抓」，兩個請求交錯的話後送的那份
                      // 會蓋掉前一個的結果，所以這裡不能只是視覺上的忙碌提示。
                      onChanged: isToggling
                          ? null
                          : (bool value) async {
                              await HapticFeedback.lightImpact();
                              // 不需要記 offset/jumpTo：列表在寫入期間不會被
                              // LoadingPage 換掉，ScrollPosition 一直活著。
                              await controller.toggleSetting(
                                  e.preferencekey, type, value);
                            },
                    )
                  ],
                ));
          },
          separatorBuilder: (context, index) {
            return const SizedBox(height: 2);
          },
          itemCount: components.notifications.length,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
        ),
      ],
    );
  }
}
