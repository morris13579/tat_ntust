import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/analytics_utils.dart';
import 'package:flutter_app/ui/other/error_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter_app/ui/pages/calendar/calendar_page.dart';
import 'package:flutter_app/ui/pages/course_table/course_table_page.dart';
import 'package:flutter_app/ui/pages/other/other_page.dart';
import 'package:flutter_app/ui/pages/score/score_page.dart';
import 'package:flutter_app/ui/pages/subsystem/sub_system_page.dart';

class MainController extends GetxController {
  final pageController = PageController();
  RxInt currentIndex = 0.obs;
  RxList<Widget> pageList = <Widget>[].obs;

  var isProfileLoading = false.obs;
  Rxn<MoodleProfileEntity> profile = Rxn();

  @override
  Future<void> onInit() async {
    super.onInit();

    pageList.addAll([
      CourseTablePage(),
      SubSystemPage(),
      CalendarPage(),
      ScoreViewerPage(),
      OtherPage()
    ]);
  }

  @override
  Future<void> onReady() async {
    super.onReady();
    final isAvailable = await _checkMoodle();

    if(isAvailable) {
      await _getMoodleProfile();
    }
  }

  /// Event Handler
  void onBottomNavigationTap(int index) {
    pageController.jumpToPage(index);
  }

  void onPageChanged(int index) {
    currentIndex.value = index;

    String screenName = pageList[index].toString();
    AnalyticsUtils.setScreenName(screenName);
  }

  /// Private Method
  Future<bool> _checkMoodle() async {
    final isMoodleAvailable = await MoodleWebApiConnector.isMoodleTokenAvailable();
    if(isMoodleAvailable) {
      return true;
    }

    final status = await MoodleWebApiConnector.login(Model.instance.getAccount(), Model.instance.getPassword());
    if(status == MoodleWebApiConnectorStatus.loginFail || status == MoodleWebApiConnectorStatus.unknownError) {
      await ErrorDialog(ErrorDialogParameter(
        title: R.current.error,
        dialogType: DialogType.error,
        desc: R.current.loginMoodleError,
        okResult: false,
        btnOkText: R.current.sure,
        offCancelBtn: true,
      )).show();
      return false;
    }

    return true;
  }

  Future<void> _getMoodleProfile() async {
    try {
      isProfileLoading.value = true;
      profile.value = await MoodleWebApiConnector.getProfile();
    } catch (e) {
      Log.e(e);
    } finally {
      isProfileLoading.value = false;
    }
  }
}
