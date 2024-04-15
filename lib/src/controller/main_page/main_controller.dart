import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/ad/ad_manager.dart';
import 'package:flutter_app/src/file/my_downloader.dart';
import 'package:flutter_app/src/notifications/notifications.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/src/util/language_utils.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/src/util/route_utils.dart';
import 'package:flutter_app/src/version/app_version.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:flutter_app/ui/pages/calendar/calendar_page.dart';
import 'package:flutter_app/ui/pages/course_table/course_table_page.dart';
import 'package:flutter_app/ui/pages/other/other_page.dart';
import 'package:flutter_app/ui/pages/score/score_page.dart';
import 'package:flutter_app/ui/pages/subsystem/sub_system_page.dart';
import 'package:get/get.dart';

import '../../R.dart';

class MainController extends GetxController {
  final pageController = PageController();
  RxInt currentIndex = 0.obs;
  RxList<Widget> pageList = <Widget>[].obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await appInit();
  }

  Future<void> appInit() async {
    var context = Get.context;
    if(context == null) {
      throw Exception("BuildContext is null");
    }

    R.set(context);
    bool catchError = await Model.instance.getInstance(); //一定要先getInstance()不然無法取得資料
    try {
      if (!(await Model.instance.getAgreeContributor())) {
        RouteUtils.toAgreePrivacyPolicyScreen();
        Get.delete<MainController>();
        return;
      }
      await RemoteConfigUtils.init();
      if(context.mounted) {
        await LanguageUtils.init(context);
      }
      APPVersion.initAndCheck().then((needUpdate) {
        if (!needUpdate) {
          RemoteConfigUtils.showAnnouncementDialog();
        }
      });
      AdManager.init();
      Log.init();
      await MyDownloader.init();
      await Notifications.instance.init();

      pageList.addAll([
        const CourseTablePage(),
        const SubSystemPage(),
        const CalendarPage(),
        const ScoreViewerPage(),
        const OtherPage()
      ]);
      Get.forceAppUpdate();
    } catch (e, stack) {
      Log.eWithStack(e.toString(), stack);
    }
    if (catchError) {
      await Future.delayed(const Duration(milliseconds: 500));
      ErrorDialogParameter parameter =
      ErrorDialogParameter(desc: R.current.loadDataFail);
      parameter.btnCancelOnPress = null;
      parameter.btnOkText = R.current.sure;
      await ErrorDialog(parameter).show();
    }
  }

  void onBottomNavigationTap(int index) {
    pageController.jumpToPage(index);
  }

  void onPageChanged(int index) {
    currentIndex.value = index;

    String screenName = pageList[index].toString();
    AnalyticsUtils.setScreenName(screenName);
  }
}