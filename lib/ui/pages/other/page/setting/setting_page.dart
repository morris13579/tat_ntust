import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/file/file_store.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/document_utils.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/other/listview_animator.dart';
import 'package:flutter_app/ui/pages/other/page/setting/moodle_setting_page.dart';
import 'package:flutter_app/ui/pages/other/page/setting/theme_setting_page.dart';
import 'package:get/get.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  String downloadPath = "";

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized()
        .addPostFrameCallback((timeStamp) async {
      await _getDownloadPath();
    });
  }

  Future<void> _getDownloadPath() async {
    String path = await FileStore.findLocalPath(context);
    setState(() {
      downloadPath = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> listViewData = [
      _buildLanguageSetting(),
      _buildThemeSetting(),
      _buildMoodleSetting(),
      _buildFolderPathSetting()
    ];

    if (Platform.isAndroid) {
      listViewData.insert(1, _buildOpenExternalVideoSetting());
    }

    return Scaffold(
      appBar: baseAppbar(title: R.current.setting),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: listViewData.length,
        itemBuilder: (context, index) {
          return WidgetAnimator(listViewData[index]);
        },
        separatorBuilder: (context, index) {
          return const SizedBox(
            height: 4,
          );
        },
      ),
    );
  }

  Widget _buildLanguageSetting() {
    return _buildItemWrapper(
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    R.current.languageSwitch,
                    style: TextStyle(color: Get.theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    R.current.willRestart,
                    style: TextStyle(
                        fontSize: 14,
                        color: Get.theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
                value: LanguageUtils.getLangIndex() == LangEnum.en,
                onChanged: (value) async {
                  int langIndex = 1 - LanguageUtils.getLangIndex().index;
                  await LanguageUtils.setLangByIndex(
                      LangEnum.values.toList()[langIndex]);
                  Get.find<MainController>().pageController.jumpToPage(0);
                  Get.back();
                  setState(() {});
                })
          ],
        ),
        () {});
  }

  Widget _buildOpenExternalVideoSetting() {
    return _buildItemWrapper(
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    R.current.openExternalVideo,
                    style: TextStyle(color: Get.theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    R.current.openExternalVideoHint,
                    style: TextStyle(
                        fontSize: 14,
                        color: Get.theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
                value: Model.instance.getOtherSetting().useExternalVideoPlayer,
                onChanged: (value) async {
                  setState(() {
                    Model.instance.getOtherSetting().useExternalVideoPlayer =
                        value;
                    Model.instance.saveOtherSetting();
                  });
                })
          ],
        ),
        () {});
  }

  Widget _buildThemeSetting() {
    return _buildItemWrapper(
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    R.current.theme_setting,
                    style: TextStyle(color: Get.theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    R.current.theme_setting_description,
                    style: TextStyle(
                        fontSize: 14,
                        color: Get.theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right,
              size: 20,
            ),
          ],
        ), () {
      Get.to(() => const ThemeSettingPage());
    });
  }

  Widget _buildMoodleSetting() {
    return _buildItemWrapper(
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    R.current.moodle_setting,
                    style: TextStyle(color: Get.theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    R.current.moodle_setting_description,
                    style: TextStyle(
                        fontSize: 14,
                        color: Get.theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right,
              size: 20,
            ),
          ],
        ), () {
      Get.to(() => const MoodleSettingPage());
    });
  }

  Widget _buildFolderPathSetting() {
    return Visibility(
      visible: downloadPath.isNotEmpty,
      child: _buildItemWrapper(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                R.current.downloadPath,
                style: TextStyle(color: Get.theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                downloadPath,
                style: TextStyle(
                    fontSize: 14,
                    color: Get.theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ), () async {
        String? directory = await DocumentUtils.choiceFolder();
        if (directory != null) {
          setState(() {
            downloadPath = directory;
          });
        }
      }),
    );
  }

  Widget _buildItemWrapper(Widget child, Function() onClick) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onClick,
      child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
              color: Get.theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: child),
    );
  }
}
