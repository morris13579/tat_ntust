import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/setting/moodle_setting_controller.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';
import 'package:flutter_app/ui/components/page/base_page.dart';
import 'package:get/get.dart';

class MoodleSettingPage extends GetView<MoodleSettingController> {
  const MoodleSettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(MoodleSettingController());

    return Obx(() {
      return BasePage(
        title: R.current.moodle_setting,
        isLoading: controller.isLoading.value,
        isError: controller.isError.value,
        errorMsg: controller.errorMsg.value,
        isSubPage: true,
        bottom: controller.tabController == null ? null : TabBar(
          controller: controller.tabController,
          tabs: controller.tab.map((e) => Tab(text: e.displayname)).toList(),
        ),
        child: TabBarView(
            controller: controller.tabController,
            children: controller.tab.map((element) => _buildSettingList(element.name)).toList()),
      );
    });
  }

  Widget _buildSettingList(type) {
    return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemBuilder: (context, index) {
          var item = controller.settingList[index];
          return _buildSettingItem(item, type);
        },
        separatorBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 6.0),
            child: Divider(
              color: Colors.grey,
            ),
          );
        },
        itemCount: controller.settingList.length);
  }

  Widget _buildSettingItem(
      MoodleSettingPreferencesComponents components, String type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0, right: 12, bottom: 6),
          child: Text(
            components.displayname,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Column(
            children: components.notifications.map((e) {
          return SwitchListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: Text(
              e.displayname,
            ),
            value: e.processors
                .where((element) => element.name == type && element.enabled)
                .isNotEmpty,
            contentPadding: const EdgeInsets.only(left: 12, right: 6),
            onChanged: (bool value) async {
              await controller.toggleSetting(e.preferencekey, type, value);
            },
          );
        }).toList())
      ],
    );
  }
}
