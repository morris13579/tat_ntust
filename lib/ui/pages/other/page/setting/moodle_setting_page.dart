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
        bottom: controller.tabController == null
            ? null
            : TabBar(
                controller: controller.tabController,
                tabs: controller.tab
                    .map((e) => Tab(text: e.displayname))
                    .toList(),
              ),
        child: TabBarView(
            controller: controller.tabController,
            children: controller.tab
                .map((element) => _buildSettingList(element.name))
                .toList()),
      );
    });
  }

  Widget _buildSettingList(type) {
    return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        itemBuilder: (context, index) {
          var item = controller.settingList[index];
          return _buildSettingItem(item, type);
        },
        separatorBuilder: (context, index) {
          return const SizedBox(height: 14);
        },
        itemCount: controller.settingList.length);
  }

  Widget _buildSettingItem(MoodleSettingPreferencesComponents components, String type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8),
          child: Text(
            components.displayname,
            style: TextStyle(fontWeight: FontWeight.w600, color: Get.theme.colorScheme.onSurface),
          ),
        ),
        ListView.separated(
          itemBuilder: (context, index) {
            final e = components.notifications[index];
            const baseRadius = 14.0;
            const subRadius = 4.0;
            BorderRadius? borderRadius;

            if (components.notifications.length == 1) {
              borderRadius = BorderRadius.circular(baseRadius);
            } else if (index == 0) {
              borderRadius = const BorderRadius.vertical(
                  top: Radius.circular(baseRadius),
                  bottom: Radius.circular(subRadius));
            } else if (index == components.notifications.length - 1) {
              borderRadius = const BorderRadius.vertical(
                  top: Radius.circular(subRadius),
                  bottom: Radius.circular(baseRadius));
            } else {
              borderRadius = BorderRadius.circular(subRadius);
            }

            return Container(
                decoration: BoxDecoration(
                    color: Get.theme.colorScheme.surfaceContainer,
                    borderRadius: borderRadius),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                child: Row(
                  children: [
                    Text(
                      e.displayname,
                      style: TextStyle(
                          color: Get.theme.colorScheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: e.processors
                          .where((element) =>
                              element.name == type && element.enabled)
                          .isNotEmpty,
                      onChanged: (bool value) async {
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
