import 'dart:async';

import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/src/controller/course_member/course_member_controller.dart';
import 'package:flutter_app/src/util/remote_config_utils.dart';
import 'package:flutter_app/ui/pages/announcement/announcement_center_page.dart';
import 'package:flutter_app/ui/pages/announcement/announcement_center_preview_page.dart';
import 'package:flutter_app/ui/pages/announcement/announcement_page.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/course/course_main_extra_json.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_app/src/repository/moodle_repository.dart';
import 'package:flutter_app/src/util/upcoming_event_utils.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/ui/components/page/inline_error_view.dart';
import 'package:flutter_app/ui/pages/course_data/course_data_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_folder_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_info_page.dart';
import 'package:flutter_app/ui/pages/course_detail/course_detail_page.dart';
import 'package:flutter_app/ui/pages/classroom/classroom_page.dart';
import 'package:flutter_app/ui/pages/course_member/course_member_page.dart';
import 'package:flutter_app/ui/pages/log_console/log_console.dart';
import 'package:flutter_app/ui/pages/other/page/about_page.dart';
import 'package:flutter_app/ui/pages/other/page/privacy_policy_page.dart';
import 'package:flutter_app/ui/pages/other/page/profile_page.dart';
import 'package:flutter_app/ui/pages/other/page/contributors_page.dart';
import 'package:flutter_app/ui/pages/other/page/dev_page.dart';
import 'package:flutter_app/ui/pages/other/page/setting/setting_page.dart';
import 'package:flutter_app/ui/pages/other/page/store_edit_page.dart';
import 'package:flutter_app/ui/pages/score/moodle_course_grades_page.dart';
import 'package:flutter_app/ui/pages/subsystem/sub_system_page.dart';
import 'package:flutter_app/ui/pages/web_view/inapp_web_view_page.dart';
import 'package:flutter_app/ui/screen/privacy_policy/privacy_policy_screen.dart';
import 'package:flutter_app/ui/screen/login/login_screen.dart';
import 'package:flutter_app/ui/screen/main_screen.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

class RouteUtils {
  /// 啟動時的公告彈窗。沒有要顯示的公告就什麼都不做——使用者主動查看的入口
  /// 已經是 [toAnnouncementCenter]，那一頁有自己的空狀態。
  static Future<void> showAnnouncement({bool test = false}) async {
    final request = await RemoteConfigUtils.resolveAnnouncement(test: test);
    if (request == null) return;
    await Get.to(
      () => AnnouncementPage(
        info: request.info,
        countDown: request.countDown,
      ),
      transition: Transition.downToUp,
    );
  }

  /// 「公告與通知」頁。啟動彈窗（[showAnnouncement]）完全不受影響，這一頁只是
  /// 給同一批 Remote Config 公告一個常駐的家，外加 Moodle 站內通知。
  static Future<void> toAnnouncementCenter() async {
    await Get.to(
      () => const AnnouncementCenterPage(openWebView: toWebViewPage),
      transition: transition,
    );
  }

  static Transition transition =
      (Platform.isAndroid) ? Transition.downToUp : Transition.cupertino;

  /// 通知頁的假資料預覽，只掛在開發者選單——真實帳號常常一則通知都沒有，
  /// 設計稿畫的那幾種狀態平常根本看不到。
  static Future<void> toNotificationPreviewPage() async {
    await Get.to(
      () => const AnnouncementCenterPreviewPage(),
      transition: transition,
    );
  }

  static Future toDevPage() async {
    return await Get.to(
      () => const DevPage(),
      transition: transition,
    );
  }

  static Future toCourseDataPage(CourseInfoJson courseInfo,
      {int initialTab = 0}) async {
    return await Get.to(
      () => CourseDataPage(courseInfo, initialTab: initialTab),
      transition: transition,
    );
  }

  /// 「Moodle 目前成績」。點一列開那門課的 Moodle 成績分頁——那一段導頁在這裡
  /// 注入，頁面本身不 import 這個檔案（見 docs/ARCHITECTURE.md「UI 慣例」）。
  /// 課程頁只讀 `main.course` 的 id 與 name，所以現組一個最小的 CourseInfoJson
  /// 就夠；內部 id 由 MoodleRepository 用課號查回來（多半是快取命中）。
  static Future<void> toMoodleCourseGrades() async {
    await Get.to(
      () => MoodleCourseGradesPage(
        onOpenCourse: (course) => toCourseDataPage(
          CourseInfoJson(
            main: CourseMainInfoJson(
              course: CourseMainJson(id: course.courseId, name: course.name),
            ),
          ),
          initialTab: CourseDataPage.scoreTab,
        ),
      ),
      transition: transition,
    );
  }

  /// 行事曆的待辦點下去要開的 App 內頁面。開不成回 false，呼叫端就照舊開
  /// WebView——站台事件、認不出課號、以及沒有 App 內頁面的模組都會走那條。
  ///
  /// 要開哪一頁不是從事件本身判斷的，而是拿 cmid 去那門課的模組表對出真正的
  /// `Modules` 再交給 [CourseModuleActions]：事件的 `instance` 在 NTUST 回的是
  /// cmid（見 `UpcomingEventUtils.cmidOf`），而檔案分頁點模組走的也是
  /// [CourseModuleActions]，共用同一份兩邊才不會走鐘。
  ///
  /// 課程模組表多半是快取命中；抓不到就當作開不成，不會卡在轉圈。
  static Future<bool> tryOpenUpcomingEvent(
      BuildContext context, MoodleActionEvent event) async {
    final target = UpcomingEventUtils.targetOf(event);
    if (target == null) return false;
    final courseInfo = CourseInfoJson(
      main: CourseMainInfoJson(
        course: CourseMainJson(id: target.courseId, name: target.courseName),
      ),
    );
    final sections =
        (await MoodleRepository.instance.getCourseDirectory(target.courseId))
            .dataOrNull;
    if (sections == null) return false;
    final module = UpcomingEventUtils.moduleOf(sections, target.cmid);
    if (module == null) return false;
    if (!context.mounted) return true;
    CourseModuleActions(courseInfo).handle(context, module);
    return true;
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

  static Future toCourseDetailPage(
      SemesterJson semester, CourseInfoJson courseInfo) async {
    return await Get.to(
      () => CourseDetailPage(courseInfo, semester),
      transition: transition,
    );
  }

  /// 修課學生名單。[controller] 由課程頁持有並負責 dispose——返回再進來要能
  /// 直接畫上一次的結果，這裡不可以順手 new 一顆。
  static Future toCourseMemberPage(
    CourseMemberController controller, {
    required String courseName,
    required int memberCount,
  }) async {
    return await Get.to(
      () => CourseMemberPage(
        controller: controller,
        courseName: courseName,
        knownMemberCount: memberCount,
        errorBuilder: (message, onRetry) =>
            InlineErrorView(message: message, onRetry: onRetry),
      ),
      transition: transition,
    );
  }

  /// 空教室。錯誤畫面由這裡注入，那一頁本身不 import 路由表
  /// （見 docs/ARCHITECTURE.md「UI 慣例」）。
  ///
  /// [date] 與 [section] 是從課表的空堂進來時帶的時段，兩個都給才生效；
  /// 都不給就開在「現在」。
  static Future toClassroomPage({DateTime? date, int? section}) async {
    return await Get.to(
      () => ClassroomPage(
        initialDate: date,
        initialSection: section,
        errorBuilder: (message, onRetry) =>
            InlineErrorView(message: message, onRetry: onRetry),
      ),
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

  /// 資訊系統。錯誤畫面與 WebView 開啟器都在這裡注入，那一頁本身不
  /// import 路由表（見 docs/ARCHITECTURE.md「UI 慣例」）。
  /// [serviceId] 帶進來就只看那一個分類（「更多」頁的四張分類卡），
  /// null 是全部服務。
  static Future toSubSystemPage({String? serviceId}) async {
    return await Get.to(
      () => SubSystemPage(
        serviceId: serviceId,
        errorBuilder: (message) => ErrorPage(errorMsg: message),
        openWebView: (title, url) => toWebViewPage(title, url),
        openClassroom: () => unawaited(toClassroomPage()),
      ),
      transition: transition,
    );
  }

  /// 個人資訊。頭貼與「前往學籍資料」都是呼叫端的動作，所以整包傳進去。
  static Future toProfilePage({
    required Future<void> Function() onChangeAvatar,
    required void Function() onOpenStudentRecord,
  }) async {
    return await Get.to(
      () => ProfilePage(
        onChangeAvatar: onChangeAvatar,
        onOpenStudentRecord: onOpenStudentRecord,
      ),
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
    // Moodle 的頁面先換成 autologin 網址，WebView 才不會停在登入頁；換不到
    // 就原樣回來。有換到時把原網址一起帶著，鑰匙被拒時 WebView 才有地方退。
    final target = await MoodleWebApiConnector.autologinUrl(url);
    return await Get.to(
      () => InAppWebViewPage(
        title: title,
        url: WebUri(target),
        fallbackUrl: target == url ? null : WebUri(url),
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
    return await Get.to(
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

  /// 登出後回登入頁。**整個堆疊換掉，不是 push。**
  ///
  /// 用 [toLoginScreen] 那種 push 會把已登出的主畫面留在底下，返回鍵一按就
  /// 回到一張沒有資料的課表。登入成功走的是 [toMainScreen]（同樣是 offAll），
  /// 所以兩邊都不會留下走得回去的死路。
  ///
  /// `Get.offAll` 同時是這個專案重建 controller 的機制（見 `AppBindings` 的
  /// fenix 註解），登出後那些 controller 會連同殘留狀態一起被丟掉。
  static Future toLoginScreenAsRoot() async {
    return await Get.offAll(
      () => const LoginScreen(),
      transition: transition,
    );
  }

  static Future toMainScreen() async {
    return await Get.offAll(
      () => const MainScreen(),
      transition: transition,
    );
  }
}
