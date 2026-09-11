import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/src/R.dart';
import 'package:flutter_app/src/connector/moodle_webapi_connector.dart';
import 'package:flutter_app/ui/service/file_download.dart';
import 'package:flutter_app/src/model/course_table/course_table_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/util/open_utils.dart';
import 'package:flutter_app/ui/routes/route_utils.dart';
import 'package:flutter_app/ui/components/custom_appbar.dart';
import 'package:flutter_app/ui/components/page/error_page.dart';
import 'package:flutter_app/src/util/my_toast.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_assignment_detail_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_forum_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_html_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/sub_page/course_quiz_detail_page.dart';
import 'package:flutter_app/ui/pages/course_data/screen/widgets/course_section_list.dart';
import 'package:get/get.dart';

/// 課程模組被點到時要做什麼。檔案分頁的就地展開與這一頁共用同一份，
/// 兩邊的行為才不會走鐘；路由與 ErrorPage 只在這裡出現一次。
class CourseModuleActions {
  const CourseModuleActions(this.courseInfo);

  final CourseInfoJson courseInfo;

  void handle(BuildContext context, Modules ap) {
    switch (ap.modname) {
      case "forum":
        // Modules.instance 就是 forum id；ErrorPage 與 RouteUtils 由這裡注入。
        unawaited(Get.to(() => CourseForumPage(
              courseInfo,
              forumId: ap.instance,
              forumName: ap.name,
              forumUrl: ap.url,
              errorBuilder: (message) => ErrorPage(errorMsg: message),
              openWebView: RouteUtils.toWebViewPage,
            )));
        break;
      case "assign":
        // Modules.instance 就是 assign id；ErrorPage 與 RouteUtils 由這裡注入。
        unawaited(Get.to(() => CourseAssignmentDetailPage(
              courseInfo,
              assignId: ap.instance,
              errorBuilder: (message) => ErrorPage(errorMsg: message),
              openWebView: RouteUtils.toWebViewPage,
            )));
        break;
      case "quiz":
        // Modules.instance 就是 quiz id；ErrorPage 與 RouteUtils 由這裡注入。
        unawaited(Get.to(() => CourseQuizDetailPage(
              courseInfo,
              quizId: ap.instance,
              errorBuilder: (message) => ErrorPage(errorMsg: message),
              openWebView: RouteUtils.toWebViewPage,
            )));
        break;
      case "folder":
        // 空資料夾也進得去：資料夾頁自己畫空狀態，比一句 toast 清楚。
        unawaited(RouteUtils.toCourseFolderPage(courseInfo, ap));
        break;
      case "label":
        break;
      case "url":
        if (ap.contents.isEmpty) {
          MyToast.show(R.current.nothingHere);
          return;
        }
        unawaited(OpenUtils.launchURL(ap.contents.first.fileurl));
        break;
      case "page":
        unawaited(Get.to(() => CourseHtmlPage(ap: ap)));
        break;
      case "resource":
      default:
        // contents 可能是空的（模組沒有檔案或看不到），先前這裡直接取 first，
        // 例外被 fire-and-forget 吃掉，使用者只看到點了沒反應。
        final file = ap.contents.isEmpty ? null : ap.contents.first;
        if (file == null) {
          MyToast.show(R.current.nothingHere);
          return;
        }
        String dirName = courseInfo.main.course.name;
        // 下載自己有通知列進度，這裡不等它結束才不會卡住 handler。
        unawaited(FileDownload.download(context,
            MoodleWebApiConnector.fileUrlWithToken(file.fileurl), dirName,
            name: file.filename));
    }
  }
}

/// 單一段（週次／主題）的全頁版本。檔案分頁現在就地展開，這一頁留給
/// 「從別的地方直接開一整段」的入口。
class CourseInfoPage extends StatelessWidget {
  final CourseInfoJson courseInfo;
  final MoodleCoreCourseGetContents contents;

  const CourseInfoPage(
    this.courseInfo,
    this.contents, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final actions = CourseModuleActions(courseInfo);
    final modules = contents.modules;
    return Scaffold(
      appBar: baseAppbar(title: contents.name),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        itemCount: modules.length,
        itemBuilder: (context, index) => CourseModuleRow(
          module: modules[index],
          index: index,
          length: modules.length,
          onTap: (module) => actions.handle(context, module),
        ),
      ),
    );
  }
}
