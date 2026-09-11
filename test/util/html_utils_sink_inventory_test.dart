import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `HtmlUtils.clean` 的 sink 盤點守門測試。
///
/// html_utils.dart 的文件註解說「新增 sink 前請重跑這個盤點」，但那句話本身
/// 沒有任何強制力：真的有人把 `Modules.name` 接到 `HtmlWidget` 上時，
/// 不會有任何測試變紅，只會有一段沒人重讀的註解。
/// 而 html_utils_sink_contract_test.dart 只斷言 `clean()` 的字串輸出，
/// 同樣管不到「下游多了一個 HTML sink」。
///
/// 這個檔案負責把那份人工紀律變成 CI 會擋的檢查，方式是把註解裡的盤點結果
/// 寫成可執行的清單：清單一旦跟現實不符就失敗，強迫改動的人重跑盤點。
///
/// 它不是型別安全，只是原始碼掃描——但 `clean()` 回傳的是 `String`，
/// 而 `Modules.name` 也是 `String`，型別系統本來就分不出「這個字串是不是
/// 還原過實體的」。要真的用型別擋，得替 `Modules.name` 換一個 wrapper 型別，
/// 那會擴散到 json_serializable 產生的程式碼與整個 model 層，成本不成比例。
void main() {
  List<File> libDartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  /// 用 `/` 統一路徑分隔，避免在 Windows 上比對失敗。
  String normalize(String path) => path.replaceAll(r'\', '/');

  test('HtmlUtils.clean 的呼叫端清單沒有變動', () {
    // 盤點結果：只有這一個檔案在呼叫，十八處——
    // - 課程模組名（Modules.name，getCourseDirectory）
    // - 行事曆待辦的事件名與課名（MoodleActionEvent.name / activityname、
    //   MoodleActionEventCourse.fullname / shortname，actionEventsPageOf）
    // - 作業名（MoodleAssignment.name，assignmentsOf）
    // - 測驗名（MoodleQuiz.name，quizzesOf）
    // - 作業成績的顯示字串（MoodleAssignFeedback.gradefordisplay 與
    //   previousattempts[].grade.gradefordisplay，submissionStatusOf）
    // - 公告標題（Discussions.name，announcementsOf）
    // - 公告的第一篇貼文標題（Discussions.subject，announcementsOf；抓不到
    //   回覆時 rootPostOf 會把它當成貼文標題畫出來）
    // - 貼文標題（MoodleForumPost.subject，_normalizePost）
    // - 回覆用的標題（MoodleForumPost.replysubject，_normalizePost；它會被
    //   當成 subject 送回伺服器，純文字）
    // - 編輯頁要填的標題（postForEditOf 的 post.subject；下游是撰寫頁的
    //   TextField，純文字 sink）
    // - 站內通知的標題與來源名（MoodleNotification.subject /
    //   contexturlname，notificationsOf）
    // - 課程總分清單的課名與分數（fullname / shortname 與 grades[].grade，
    //   joinCourseGrades）
    // moodle_repository 的 normalizeScore 是第三個：成績項目的四個
    // `*formatted`（gradeformatted / percentageformatted / weightformatted /
    // rangeformatted），網路與快取兩條路都經過它。下游是 course_score_page
    // 的標題底下那一行與右邊的分數欄，都是 Text；同一列的 `feedback` 是
    // HtmlWidget，但那一欄刻意沒有被 clean。
    // 另一個檔案是 moodle_notification_utils：通知摘要（smallmessage /
    // fullmessage / text）先剝標籤再 clean，輸出只進 tile 的 Text。
    // 下游全是 Text 與 AppBar / WebView 標題（upcoming_events_section 的
    // tile、course_assignment_page 的列、course_assignment_detail_page 的
    // AppBar、成績列與「先前的繳交」那幾列、course_announcement_page 的清單卡片與
    // 討論串頁的 AppBar、forum_post_block 的卡片子標題與撰寫頁標題欄的 TextField、
    // moodle_course_grades_page 的課名與分數、course_quiz_detail_page 的
    // AppBar、InAppWebViewPage 的 title）。
    const expected = {
      'lib/src/connector/moodle_webapi_connector.dart',
      'lib/src/repository/moodle_repository.dart',
      'lib/src/util/moodle_notification_utils.dart',
    };

    final actual = <String>{
      for (final file in libDartFiles())
        if (file.readAsStringSync().contains('HtmlUtils.clean('))
          normalize(file.path),
    };

    expect(
      actual,
      expected,
      reason: '''
HtmlUtils.clean 的呼叫端變了。

clean() 是 escape 的反向操作：它會把 `&lt;script&gt;` 還原成 `<script>`，
所以每一個呼叫端都有義務保證輸出只流進純文字 sink（Text、AppBar 標題……）。

請重跑 html_utils.dart 註解裡的盤點：追一次新呼叫端的所有下游，確認沒有任何
一條路徑通往 HtmlWidget、WebView 或檔案路徑，然後更新該註解與這裡的清單。''',
    );
  });

  test('HtmlWidget（HTML sink）出現的檔案清單沒有變動', () {
    // 盤點結果，這四個檔案吃的分別是：
    // - moodle_html_view：共用的 Moodle 原文 HTML 算繪元件，被作業詳情頁的
    //   說明 intro / 線上文字 onlinetext / 老師回饋 comments、測驗詳情頁的
    //   測驗說明 intro 與公告討論串頁的貼文 message 餵，全是未經 clean 的原文
    // - course_section_list：Modules.description（未經 clean 的 Moodle 原文）。
    //   label 模組整列就是那段 HTML，其餘模組展開說明時也是它。這一份原本在
    //   course_info_page，檔案分頁改成就地展開時整段搬過來，來源欄位沒變
    // - course_html_page：遠端 HTML 教材原文
    // - course_score_page：成績項目的老師回饋（gradeitems[].feedback，帶 <img>）
    // 沒有任何一個吃 clean() 的輸出。
    const expected = {
      'lib/ui/components/html/moodle_html_view.dart',
      'lib/ui/pages/course_data/screen/course_score_page.dart',
      'lib/ui/pages/course_data/screen/sub_page/course_html_page.dart',
      'lib/ui/pages/course_data/screen/widgets/course_section_list.dart',
    };

    final actual = <String>{
      for (final file in libDartFiles())
        if (file.readAsStringSync().contains('HtmlWidget('))
          normalize(file.path),
    };

    expect(
      actual,
      expected,
      reason: '''
lib 底下的 HTML sink 清單變了。

這條測試就是 html_utils.dart 註解裡那句「新增 sink 前請重跑這個盤點」的
可執行版本。新增或移除 HtmlWidget 本身不是錯，但必須確認新的那一個
**不是**吃 HtmlUtils.clean() 的輸出（典型就是 Modules.name），
確認完再把檔案加進上面的清單。''',
    );
  });

  test('沒有任何 HtmlWidget 直接吃 Modules.name', () {
    // 上一條測「有沒有新的 sink」，這條測「sink 有沒有接上那條資料」：
    // clean() 過的模組名被拿去當 HTML 算繪。
    final htmlWidgetFirstArg = RegExp(r'HtmlWidget\(\s*([^,)]*)');
    final modulesName = RegExp(r'^(widget\.)?(ap|module|modules)\.name$');

    final offenders = <String>[];
    for (final file in libDartFiles()) {
      final source = file.readAsStringSync();
      for (final match in htmlWidgetFirstArg.allMatches(source)) {
        final firstArg = match.group(1)!.trim();
        if (modulesName.hasMatch(firstArg)) {
          offenders.add('${normalize(file.path)}: HtmlWidget($firstArg)');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: '''
Modules.name 被當成 HTML 餵進 HtmlWidget 了。

Modules.name 在 moodle_webapi_connector.getCourseDirectory 裡經過
HtmlUtils.clean()，也就是說裡面的 `&lt;script&gt;` 已經被還原成 `<script>`。
它只能進純文字 sink。要顯示課名請用 Text；要顯示 HTML 請改用沒有 clean 過的
欄位（例如 description）。''',
    );
  });
}
