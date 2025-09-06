import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/src/version/app_version.dart';
import 'package:flutter_app/src/version/update/app_update.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/other/listview_animator.dart';
import 'package:flutter_app/ui/other/my_toast.dart';
import 'package:flutter_app/ui/pages/password/check_password_dialog.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

enum OnListViewPress { appUpdate, contribution, privacyPolicy, version, dev }

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<StatefulWidget> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  List<Map> listViewData = [];

  static bool inDevMode = false | kDebugMode;

  @override
  void initState() {
    super.initState();
    initList();
  }

  void initList() {
    listViewData = [
      {
        "icon": "img_update.svg",
        "title": R.current.checkVersion,
        "onPress": OnListViewPress.appUpdate
      },
      {
        "icon": "img_award.svg",
        "title": R.current.Contribution,
        "onPress": OnListViewPress.contribution
      },
      {
        "icon": "img_privacy.svg",
        "title": R.current.PrivacyPolicy,
        "onPress": OnListViewPress.privacyPolicy
      },
      {
        "icon": "img_info.svg",
        "title": R.current.versionInfo,
        "onPress": OnListViewPress.version
      }
    ];
    _addDevListItem();
  }

  void _addDevListItem() {
    if (inDevMode) {
      setState(() {
        listViewData.add({
          "icon": "img_dev.svg",
          "title": R.current.developerMode,
          "onPress": OnListViewPress.dev
        });
      });
    }
  }

  int pressTime = 0;

  void _onListViewPress(OnListViewPress value) async {
    switch (value) {
      case OnListViewPress.appUpdate:
        MyToast.show(R.current.checkingVersion);
        bool result = await APPVersion.check(focusCheck: true);
        if (!result) {
          MyToast.show(R.current.isNewVersion);
        }
        break;
      case OnListViewPress.contribution:
        RouteUtils.toContributorsPage();
        break;
      case OnListViewPress.version:
        String mainVersion = await AppUpdate.getAppVersion();
        if (pressTime == 0) {
          MyToast.show(mainVersion);
        }
        pressTime++;
        Future.delayed(const Duration(seconds: 2)).then((_) {
          pressTime = 0;
        });
        if (pressTime > 3) {
          if (!inDevMode && await Get.dialog(const CheckPasswordDialog())) {
            inDevMode = true;
            _addDevListItem();
          }
        }
        break;
      case OnListViewPress.privacyPolicy:
        RouteUtils.toPrivacyPolicyPage();
        break;
      case OnListViewPress.dev:
        RouteUtils.toDevPage();
        break;
      default:
        MyToast.show(R.current.noFunction);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: baseAppbar(title: R.current.about),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: listViewData.length,
        itemBuilder: (context, index) {
          return WidgetAnimator(_buildAbout(listViewData[index]));
        },
        separatorBuilder: (context, index) {
          return const SizedBox(height: 4);
        },
      ),
    );
  }

  Widget _buildAbout(Map data) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        _onListViewPress(data['onPress']);
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: Get.theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Get.theme.colorScheme.surface),
              padding: const EdgeInsets.all(8),
              child: SvgPicture.asset("assets/image/${data['icon']}", color: Get.theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 12),
            Text(
              data['title'],
              style: TextStyle(
                  color: Get.theme.colorScheme.onSurface, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
