import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/ui/pages/course_data/course_data_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_announcement_detail_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_folder_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_info_page.dart';
import 'package:flutter_app/ui/pages/course_detail/course_detail_page.dart';
import 'package:flutter_app/ui/pages/file_viewer/file_viewer_page.dart';
import 'package:flutter_app/ui/pages/log_console/log_console.dart';
import 'package:flutter_app/ui/pages/other/page/about_page.dart';
import 'package:flutter_app/ui/pages/other/page/agree_privacy_policy_screen.dart';
import 'package:flutter_app/ui/pages/other/page/contributors_page.dart';
import 'package:flutter_app/ui/pages/other/page/dev_page.dart';
import 'package:flutter_app/ui/pages/other/page/setting/setting_page.dart';
import 'package:flutter_app/ui/pages/other/page/store_edit_page.dart';
import 'package:flutter_app/ui/pages/subsystem/sub_system_page.dart';
import 'package:flutter_app/ui/pages/web_view/inapp_web_view_page.dart';
import 'package:flutter_app/ui/screen/privacy_policy/privacy_policy_screen.dart';
import 'package:flutter_app/ui/screen/login/login_screen.dart';
import 'package:flutter_app/ui/screen/main_screen.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

class RouteUtils {
  static Transition transition =
      (Platform.isAndroid) ? Transition.downToUp : Transition.cupertino;

  static Future toSubSystemPage() async {
    return Get.to(() => const SubSystemPage(),
        transition: transition, preventDuplicates: false //必免重覆頁面時不載入
        );
  }

  static Future toDevPage() async {
    return await Get.to(
      () => const DevPage(),
      transition: transition,
    );
  }

  static Future toFileViewerPage(String title, String path) async {
    return await Get.to(
        () => FileViewerPage(
              title: title,
              path: path,
            ),
        transition: transition);
  }

  static Future toCourseDataPage(CourseInfoJson courseInfo, int index) async {
    return await Get.to(
      () => CourseDataPage(courseInfo, index),
      transition: transition,
    );
  }

  static Future toCourseFolderPage(
      CourseInfoJson courseInfo, dynamic value) async {
    return await Get.to(
      () => CourseFolderPage(courseInfo, value),
      transition: transition,
    );
  }

  static Future toCourseInfoPage(
      CourseInfoJson courseInfo, dynamic value) async {
    return await Get.to(
      () => CourseInfoPage(courseInfo, value),
      transition: transition,
    );
  }

  static Future toAnnouncementDetailPage(
      CourseInfoJson courseInfo, dynamic value) async {
    return await Get.to(
      () => CourseAnnouncementDetailPage(courseInfo, value),
      transition: transition,
    );
  }

  static Future toCourseDetailPage(
      SemesterJson semester, CourseInfoJson courseInfo, int index) async {
    return await Get.to(
      () => CourseDetailPage(courseInfo, semester, index),
      transition: transition,
    );
  }

  static Future toPrivacyPolicyPage() async {
    return await Get.to(
      () => const PrivacyPolicyPage(),
      transition: transition,
    );
  }

  static Future toContributorsPage() async {
    return await Get.to(
      () => ContributorsPage(),
      transition: transition,
    );
  }

  static Future toAboutPage() async {
    return await Get.to(
      () => const AboutPage(),
      transition: transition,
    );
  }

  static Future toSettingPage() async {
    return await Get.to(
      () => const SettingPage(),
      transition: transition,
    );
  }

  static Future toWebViewPage(String title, String url,
      {bool openWithExternalWebView = true,
      Function(Uri)? onWebViewDownload,
      Function(InAppWebViewController)? loadDone}) async {
    loadDone ??= (controller) {};
    return await Get.to(
      () => InAppWebViewPage(
        title: title,
        url: WebUri(url),
        openWithExternalWebView: openWithExternalWebView,
        onWebViewDownload: onWebViewDownload,
        loadDone: loadDone!,
      ),
      transition: transition,
    );
  }

  static Future toLogConsolePage() async {
    return await Get.to(
      () => LogConsole(dark: true),
      transition: transition,
    );
  }

  static Future toStoreEditPage() async {
    return await Get.to(
      () => const StoreEditPage(),
      transition: transition,
    );
  }

  static Future toAgreePrivacyPolicyScreen() async {
    return await Get.offAll(
      () => const PrivacyPolicyScreen(),
      transition: transition,
    );
  }

  static Future toLoginScreen() async {
    //return will auto jump to main screen
    bool? value = await Get.to(
      () => const LoginScreen(),
      transition: transition,
    );
    return value ?? false;
  }

  static Future toMainScreen() async {
    return await Get.offAll(
      () => const MainScreen(),
      transition: transition,
    );
  }

  static Future toAliceInspectorPage() async {
    DioConnector.instance.alice.showInspector();
  }
}
