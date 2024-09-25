import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/config/app_themes.dart';
import 'package:flutter_app/src/controller/main_page/main_controller.dart';
import 'package:flutter_app/src/file/file_store.dart';
import 'package:flutter_app/src/providers/app_provider.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/task/moodle_webapi/moodle_task.dart';
import 'package:flutter_app/src/util/document_utils.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/base_page.dart';
import 'package:flutter_app/ui/other/listview_animator.dart';
import 'package:flutter_app/ui/pages/other/page/setting/moodle_setting_page.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  String downloadPath = "";
  static const EdgeInsets contentPadding =
      EdgeInsets.only(top: 5, left: 20, right: 20);
  static ShapeBorder shape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

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
      _buildMoodleSetting(),
      _buildFolderPathSetting()
    ];

    if (Platform.isAndroid) {
      listViewData.insert(1, _buildOpenExternalVideoSetting());
    }

    return Scaffold(
      appBar: baseAppbar(title: R.current.setting),
      body: ListView.separated(
        itemCount: listViewData.length,
        itemBuilder: (context, index) {
          return WidgetAnimator(listViewData[index]);
        },
        separatorBuilder: (context, index) {
          // 顯示格線
          return Container(
            color: Colors.black12,
            height: 1,
          );
        },
      ),
    );
  }

  Widget _buildLanguageSetting() {
    return SwitchListTile.adaptive(
      contentPadding: contentPadding,
      shape: shape,
      title: Text(
        R.current.languageSwitch,
      ),
      subtitle: Text(
        R.current.willRestart,
      ),
      value: (LanguageUtils.getLangIndex() == LangEnum.en),
      onChanged: (value) async {
        int langIndex = 1 - LanguageUtils.getLangIndex().index;
        await LanguageUtils.setLangByIndex(LangEnum.values.toList()[langIndex]);
        Get.find<MainController>().pageController.jumpToPage(0);
        Get.back();
        setState(() {});
      },
    );
  }

  Widget _buildOpenExternalVideoSetting() {
    return SwitchListTile.adaptive(
      contentPadding: contentPadding,
      shape: shape,
      title: Text(
        R.current.openExternalVideo,
      ),
      subtitle: Text(
        R.current.openExternalVideoHint,
      ),
      value: Model.instance.getOtherSetting().useExternalVideoPlayer,
      onChanged: (value) {
        setState(() {
          Model.instance.getOtherSetting().useExternalVideoPlayer = value;
          Model.instance.saveOtherSetting();
        });
      },
    );
  }

  Widget _buildMoodleSetting() {
    return ListTile(
      contentPadding: contentPadding,
      shape: shape,
      title: Text(
        R.current.moodle_setting,
      ),
      subtitle: Text(
        R.current.moodle_setting_description,
      ),
      trailing: const Icon(Icons.chevron_right, size: 20,),
      onTap: () {
        Get.to(() => const MoodleSettingPage());
      },
    );
  }

  Widget _buildFolderPathSetting() {
    return Visibility(
      visible: downloadPath.isNotEmpty,
      child: ListTile(
        contentPadding: contentPadding,
        shape: shape,
        title: Text(
          R.current.downloadPath,
        ),
        subtitle: Text(
          downloadPath,
        ),
        onTap: () async {
          String? directory = await DocumentUtils.choiceFolder();
          if (directory != null) {
            setState(() {
              downloadPath = directory;
            });
          }
        },
      ),
    );
  }
}
