import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:flutter_app/debug/log/log.dart';
import 'package:flutter_app/src/connector/core/connector.dart';
import 'package:flutter_app/src/connector/core/connector_parameter.dart';
import 'package:flutter_app/src/connector/core/dio_connector.dart';
import 'package:flutter_app/src/service/interactive_login_gateway.dart';
import 'package:flutter_app/src/model/moodle_token_entity.dart';
import 'package:flutter_app/src/model/course/course_class_json.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_calendar_action_events.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_course_get_contents.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_core_enrol_get_users.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_get_grade_items.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_gradereport_overview_course_grades.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_message_popup_notifications.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_assignments.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_assign_get_submission_status.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_forum_write_status.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_draft_area.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_access_information.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_discussion_posts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forum_discussions.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_forum_get_forums_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_quizzes_by_courses.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_attempts.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_mod_quiz_get_user_best_grade.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_profile_entity.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_setting_entity.dart';
import 'package:flutter_app/src/model/moodle_webapi/moodle_user_picture.dart';
import 'package:flutter_app/src/store/model.dart';
import 'package:flutter_app/src/util/html_utils.dart';
import 'package:flutter_app/src/util/moodle_course_name_utils.dart';
import 'package:flutter_app/src/util/moodle_assign_submit_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_edit_utils.dart';
import 'package:flutter_app/src/util/moodle_forum_utils.dart';

enum MoodleWebApiConnectorStatus { loginSuccess, loginFail }

/// Moodle 的失敗一律是 HTTP 200 加 `{exception, errorcode, message}` 或
/// `warnings[]`，不判讀就是無聲失敗。刻意不留整包 body（裡面有個資）。
/// `mod_assign_start_submission` 的結果。[notOpen] 是唯一真的失敗；
/// 其餘三種都應該繼續進編輯頁。
enum AssignStartOutcome {
  /// 伺服器寫下了 `timestarted`，計時開始。
  started,

  /// `opensubmissionexists`：已經有一次在跑了，接續它。
  alreadyRunning,

  /// `timelimitnotenabled`：站台層級的 `enabletimelimit` 是關的。
  /// 沒有任何 WS 讀得到那個開關，這一則 warning 是唯一的線索。
  noTimeLimit,

  /// `submissionnotopen`：這份作業現在不開放繳交。
  notOpen,
}

/// [MoodleWebApiConnector.startSubmission] 的回傳值。沒有 `.g.dart`：
/// 不落地也不上傳。
class MoodleAssignStartResult {
  const MoodleAssignStartResult({
    required this.outcome,
    required this.submissionId,
  });

  final AssignStartOutcome outcome;

  /// 有任何 warning 時伺服器什麼都沒寫，這裡會是 0。
  final int submissionId;
}

class MoodleApiException implements Exception {
  MoodleApiException({
    required this.wsFunction,
    this.errorcode,
    this.exception,
    this.message,
    this.debugInfo,
    this.siteFunctionVersion,
    this.skippedBeforeRequest = false,
  });

  final String wsFunction;

  /// 部分失敗（warnings[]）時是第一筆 warning 的 `warningcode`。
  final String? errorcode;

  final String? exception;
  final String? message;

  /// 只有站台開了 debug 才會有；正式站通常是 null。
  final String? debugInfo;

  /// 站台回報的 function 版本，用來分辨「參數打錯」與「站台太舊」。
  final String? siteFunctionVersion;

  /// 本地在送出前就擋下來的（[MoodleWebApiConnector.wsFunctionBlocked]）。
  final bool skippedBeforeRequest;

  /// 只認 `invalidtoken`：`accessexception` 是站台沒開放這個 function，
  /// 拿它去觸發重登入只會變成無限迴圈。
  bool get isInvalidToken => errorcode == 'invalidtoken';

  @override
  String toString() {
    final buffer = StringBuffer('MoodleApiException($wsFunction');
    if (skippedBeforeRequest) buffer.write(', skipped-before-request');
    if (errorcode != null) buffer.write(', errorcode: $errorcode');
    if (exception != null) buffer.write(', exception: $exception');
    if (message != null) buffer.write(', message: $message');
    if (debugInfo != null) buffer.write(', debuginfo: $debugInfo');
    if (siteFunctionVersion != null) {
      buffer.write(', siteFunctionVersion: $siteFunctionVersion');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

class MoodleWebApiConnector {
  static const String host = "https://moodle2.ntust.edu.tw";
  static const String _webAPIUrl = "$host/webservice/rest/server.php";

  /// 站台資訊與可用 function 清單的來源。
  static const String siteInfoFunction = "core_webservice_get_site_info";

  /// 這個帳號的全部課程（含歷史學期）的來源。
  static const String enrolledCoursesFunction = "core_enrol_get_users_courses";

  /// 課程成績的來源。不用 `gradereport_user_get_grades_table`：那個回渲染好的
  /// HTML 表格，欄位一增減 DOM 走訪就靜靜地壞掉。
  static const String gradeItemsFunction = "gradereport_user_get_grade_items";

  /// 這個帳號全部課程的目前總分。@since Moodle 3.2，在
  /// MOODLE_OFFICIAL_MOBILE_SERVICE 內。
  static const String courseGradesFunction =
      "gradereport_overview_get_course_grades";

  static const String actionEventsFunction =
      "core_calendar_get_action_events_by_timesort";

  /// 往前抓幾天，讓逾期未交的還看得到。
  static const int actionEventsLookbackDays = 14;

  /// 伺服器上限就是 50，超過會直接回錯。
  static const int actionEventsLimit = 50;

  /// 滿頁時最多再翻幾頁；4 頁 200 筆已遠超一個學期會有的待辦。
  static const int actionEventsMaxPages = 4;

  static const String assignmentsFunction = "mod_assign_get_assignments";

  static const String quizzesFunction = "mod_quiz_get_quizzes_by_courses";

  /// Moodle 5.0 起改名，舊名在 5.0 標記 deprecated、6.0 移除；
  /// 站台有新的就用新的，見 [preferredQuizAttemptsFunction]。
  static const String quizAttemptsFunction = "mod_quiz_get_user_attempts";
  static const String quizUserAttemptsFunction =
      "mod_quiz_get_user_quiz_attempts";

  static const String quizBestGradeFunction = "mod_quiz_get_user_best_grade";

  /// 只有 'all' 看得到 inprogress / overdue；伺服器預設的 'finished' 會漏掉它們。
  static const String quizAttemptsStatus = "all";

  static const String forumsByCoursesFunction =
      "mod_forum_get_forums_by_courses";

  static const String forumDiscussionsFunction =
      "mod_forum_get_forum_discussions";

  static const String discussionPostsFunction =
      "mod_forum_get_discussion_posts";

  /// 回覆一篇貼文。type=write，capability 是 `mod/forum:replypost`。
  static const String addDiscussionPostFunction =
      "mod_forum_add_discussion_post";

  /// 這個討論區的 capability 快照。type=read。整份回應是
  /// `load_capability_def('mod_forum')` 執行期攤出來的，欄位集合跟著站台版本
  /// 走，每一格都是 VALUE_OPTIONAL；**沒有 `caneditownpost`**（見
  /// [MoodleForumAccess]）。這次只為了 `cancreateattachment` 打它。
  static const String forumAccessInformationFunction =
      "mod_forum_get_forum_access_information";

  /// 單獨一篇貼文，帶**資料庫裡的原文**與抓取當下的 capabilities。type=read。
  static const String discussionPostFunction = "mod_forum_get_discussion_post";

  /// 把貼文現有的附件整批複製進使用者的 draft 區。type=write。
  static const String prepareDraftAreaFunction =
      "mod_forum_prepare_draft_area_for_post";

  /// 編輯自己的貼文。type=write。
  static const String updateDiscussionPostFunction =
      "mod_forum_update_discussion_post";

  /// 刪除自己的貼文（沒有父貼文時連整串一起刪）。type=write。
  static const String deletePostFunction = "mod_forum_delete_post";

  /// `prepare_draft_area_for_post` 的 `area` 只能是 `attachment` 或 `post`，
  /// 其他值丟 `invalid_parameter_exception`（**沒有** forum errorcode）。
  static const String forumDraftAreaAttachment = "attachment";

  /// 內嵌圖片那一區。`area='post'` 才會把貼文的內嵌檔案種進 draft 區，
  /// 而且**只有它**會回 `messagetext`（附件那一區固定是 null）。
  static const String forumDraftAreaPost = "post";

  /// FORMAT_PLAIN。`messageformat` 的 VALUE_DEFAULT 是 FORMAT_HTML，
  /// 不送就等於宣告「這是 HTML」，手機上打的純文字會掉換行、`a < b` 被吃掉。
  static const String forumMessageFormatPlain = "2";

  /// 一頁抓滿；公告很少破百，超過的部分請使用者用網頁看。
  static const int announcementPerPage = 100;

  static const String submissionStatusFunction =
      "mod_assign_get_submission_status";

  /// 存一次繳交（type=write）。回的是**裸的 warnings 陣列**，見 [writeWarningOf]。
  static const String saveSubmissionFunction = "mod_assign_save_submission";

  /// 把草稿送出評分（type=write）。回傳形狀同上。
  static const String submitForGradingFunction =
      "mod_assign_submit_for_grading";

  /// 移除一次繳交（type=write，@since Moodle 4.5）。參數是 `assignid` +
  /// `userid`，不是 `assignmentid`；回的是 **Map**（`{status, warnings}`），
  /// 跟隔壁兩支的裸陣列不一樣，見 [writeObjectShapeErrorOf]。
  static const String removeSubmissionFunction = "mod_assign_remove_submission";

  /// 開始一次有時限的作答（type=write，@since Moodle 4.0）。參數只有
  /// `assignid`，伺服器寫死 `$USER->id`；回的也是 Map。
  static const String startSubmissionFunction = "mod_assign_start_submission";

  /// 把上一次的繳交複製進這一次（type=write）。參數是第三種拼法
  /// `assignmentid`，回的是裸陣列。
  ///
  /// **這一支在 `mod/assign/db/services.php` 裡沒有 `services` 鍵**，是全部
  /// `mod_assign_*` 裡唯一的一個，所以它不在 MOODLE_OFFICIAL_MOBILE_SERVICE
  /// 內，一般站台的 `site_info.functions[]` 不會列出它。
  /// [canCopyPreviousAttempt] 多數站台會是 false，那是常態不是例外。
  static const String copyPreviousAttemptFunction =
      "mod_assign_copy_previous_attempt";

  /// FORMAT_HTML。onlinetext 的 format 是 PARAM_INT。
  static const int onlineTextFormatHtml = 1;

  static const String popupNotificationsFunction =
      "message_popup_get_popup_notifications";

  static const String popupUnreadCountFunction =
      "message_popup_get_unread_popup_notification_count";

  /// @since Moodle 4.0，算的是全部 notifications 而不只 popup。
  static const String unreadNotificationCountFunction =
      "core_message_get_unread_notification_count";

  static const String markNotificationReadFunction =
      "core_message_mark_notification_read";

  static const String markAllNotificationsReadFunction =
      "core_message_mark_all_notifications_as_read";

  /// 伺服器的 limit 預設 0 ＝不限筆數，一定要自己給上限。
  static const int notificationsLimit = 50;

  /// 站內通知一次最多翻幾頁，同 [actionEventsMaxPages] 的態度：收件匣再大也
  /// 不該把開頁變成四趟以上的請求。
  static const int notificationsMaxPages = 4;

  /// 更換或移除頭貼。@since Moodle 3.2，在 MOODLE_OFFICIAL_MOBILE_SERVICE 內。
  static const String updatePictureFunction = "core_user_update_picture";

  /// webservice/upload.php 不是 wsfunction，site_info 的 functions[] 不會列它；
  /// 它的開關是 site_info 的 uploadfiles（外部服務設定裡的同一顆）。
  static const String uploadEndpoint = "$host/webservice/upload.php";

  /// multipart 欄位名，upload.php 用 `foreach($_FILES)` 掃，名字本身不重要；
  /// 沿用官方文件與 App 用的 file_1，好對照。
  static const String uploadFieldName = "file_1";

  /// 上傳整個 body 的總時間上限。BaseOptions 的 5 秒是給表單 POST 的，
  /// 照片撐不過去（IOHttpClientAdapter 把 sendTimeout 套在整條 addStream 上）。
  static const Duration uploadSendTimeout = Duration(seconds: 90);

  /// passport 必須跟著回傳：signature 是 `md5(wwwroot + passport)`，驗它才能
  /// 確定 token 來自我們發出的那次請求。亂數必須維持密碼學等級。
  static ({String url, String passport}) buildLoginLaunch() {
    final passport = Random.secure().nextInt(1000000).toString();
    return (
      url: "$host/admin/tool/mobile/launch.php"
          "?service=moodle_mobile_app&passport=$passport"
          "&urlscheme=moodlemobile&lang=zh_tw",
      passport: passport,
    );
  }

  /// 伺服器算的是 `md5($CFG->wwwroot . $passport)`；wwwroot 的 scheme 未必與
  /// 這裡的 host 相同，所以 https/http 各算一次。
  static bool verifyLoginSignature(String signature, String passport) {
    for (final base in [host, host.replaceFirst('https://', 'http://')]) {
      final expected = md5.convert(utf8.encode('$base$passport')).toString();
      if (expected == signature) return true;
    }
    return false;
  }

  static String? _wsToken;

  /// process 內的 token 快取；持久化由 [MoodleSessionStore] 負責，登出時兩邊都要清。
  static String? get wsToken => _wsToken;

  /// 換 token 等於換身分，跟著這顆 token 的快取全部作廢；清除掛在 setter 上
  /// 是因為改 token 的地方有三處，漏掉任何一個就是跨帳號洩漏。
  static set wsToken(String? value) {
    if (_wsToken != value) {
      userId = null;
      siteInfo = null;
      _usersCoursesCache = null;
      // lockout 與 fatal 旗標都是伺服器按使用者算的，換 token 就重來。
      autologinLastKeyAt = null;
      autologinDisabled = false;
    }
    _wsToken = value;
  }

  /// 這顆 token 的可用 function 清單，由打過 site_info 的幾個方法順手填上；
  /// 換 token 時由 [wsToken] 的 setter 清掉。
  static MoodleProfileEntity? siteInfo;

  /// 讀取路徑一律「失敗回 null」，錯誤細節走這條旁路給 AuthSession 接重登入。
  /// 刻意不在 connector 內自動重登入：背景任務憑空彈出登入畫面比失敗更糟。
  static void Function(MoodleApiException error)? onApiError;

  /// 舊路徑 `?token=<wsToken>` 會把長效憑證放進 src 與 Referer，所以優先走
  /// `tokenpluginfile.php/<userprivateaccesskey>/…`；但站台可停用它，故執行期
  /// 探測一次。null 代表還沒探測；這是站台性質，換 token 不清。
  static bool? tokenPluginFileWorks;

  static Future<void>? _tokenPluginFileProbing;

  /// 進行中的探測，測試用來等它結束；正式流程不 await，探測完成前一律走舊路徑。
  static Future<void>? get tokenPluginFileProbe => _tokenPluginFileProbing;

  /// 探測的實作。抽成可替換的欄位，測試才不必真的連網路。
  static Future<bool> Function(String url) tokenPluginFileProber =
      _headTokenPluginFile;

  /// 把探測狀態清回「還沒探測」。測試用。
  static void resetTokenPluginFileProbe() {
    tokenPluginFileWorks = null;
    _tokenPluginFileProbing = null;
  }

  /// `<前綴>[/webservice]/pluginfile.php` 這一段。
  static final RegExp _pluginFileSegment =
      RegExp(r'(/webservice)?/pluginfile\.php');

  /// 把路徑裡的 `[/webservice]/pluginfile.php` 換成 `/tokenpluginfile.php/<key>`，
  /// query 原封不動帶著走（`forcedownload=1` 之類必須留著）；不能改寫回 null。
  static String? tokenPluginFileUrl(String fileUrl) {
    final accessKey = siteInfo?.userprivateaccesskey ?? "";
    if (accessKey.isEmpty) return null;

    // 只動 '?' 前面那一段：query 裡也可能出現 pluginfile.php，那不是要換的。
    final queryAt = fileUrl.indexOf('?');
    final path = queryAt < 0 ? fileUrl : fileUrl.substring(0, queryAt);
    final query = queryAt < 0 ? "" : fileUrl.substring(queryAt);
    // 已經帶著 token 的網址不改寫：tokenpluginfile 不吃 wsToken，改寫只會
    // 生出一個兩種憑證都在的怪網址，token 照樣外流。
    if (query.contains("token=")) return null;

    final match = _pluginFileSegment.firstMatch(path);
    if (match == null) return null;
    return "${path.substring(0, match.start)}"
        "/tokenpluginfile.php/$accessKey"
        "${path.substring(match.end)}$query";
  }

  /// 只讀回應標頭、不下載內容：附件可能是幾十 MB 的 PDF。
  /// 非 200 會拋，交給呼叫端當成「不支援」。
  static Future<bool> _headTokenPluginFile(String url) async {
    await DioConnector.instance.getHeadersByGet(ConnectorParameter(url));
    return true;
  }

  static Future<void> _probeTokenPluginFile(String probeUrl) {
    final running = _tokenPluginFileProbing;
    if (running != null) return running;
    return _tokenPluginFileProbing = () async {
      try {
        tokenPluginFileWorks = await tokenPluginFileProber(probeUrl);
      } catch (e) {
        // 失敗一律當成不支援：走舊路徑最多多帶一次 token，切過去卻打不開
        // 則是每個附件都開不了。這個 process 不再重試。
        tokenPluginFileWorks = false;
        Log.e("tokenpluginfile probe failed: $e");
      }
    }();
  }

  /// [uri] 是不是自家站台（只比 host，不看 scheme）。
  static bool isOwnHost(Uri? uri) => uri != null && uri.host == _moodleHost;

  /// 自家站台的 pluginfile.php 網址——只有這種圖要 App 自己帶 token 去抓。
  static bool isOwnPluginFileUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != "https" || !isOwnHost(uri)) return false;
    return _pluginFileSegment.hasMatch(uri.path);
  }

  /// 是不是 autologin.php 本身。成功時它會 303 轉走，停在這裡就代表鑰匙被拒。
  static bool isAutologinScript(Uri? uri) =>
      isOwnHost(uri) && uri!.path == autologinScriptPath;

  /// 產生可直接取用的 Moodle 檔案網址。非自家 host 一律原樣回傳、不附憑證，
  /// 否則 wsToken 會被送進別人的 access log；探測未完成則退回舊的 `?token=`。
  static String fileUrlWithToken(String fileUrl) {
    final token = wsToken;
    if (token == null) return fileUrl;
    final uri = Uri.tryParse(fileUrl);
    if (!isOwnHost(uri)) {
      Log.e("refuse to attach token to a foreign host: ${uri?.host}");
      return fileUrl;
    }

    final tokenUrl = tokenPluginFileUrl(fileUrl);
    if (tokenUrl != null) {
      if (tokenPluginFileWorks == true) return tokenUrl;
      // 順手拿這個真實網址探一次。這次仍回舊路徑：探測是非同步的，
      // 而這個方法會在 build() 裡被呼叫，等不了。
      if (tokenPluginFileWorks == null) {
        unawaited(_probeTokenPluginFile(tokenUrl));
      }
    }
    return Connector.uriAddQuery(_webservicePluginFileUrl(fileUrl), {
      "token": token,
    });
  }

  /// `?token=` 只有 `webservice/pluginfile.php` 認得：`pluginfile.php` 走的是
  /// 瀏覽器 session（`NO_MOODLE_COOKIES` 只設在前者），帶著 token 一樣被踢去
  /// 登入頁。討論區的附件與內嵌圖片走 `stored_file_exporter`，它組網址用的是
  /// `make_pluginfile_url()`——正是不吃 token 的那一支，所以加憑證之前要先換
  /// 過去。官方 App 的 `CoreSites.fixPluginfileURL()` 做的也是同一件事。
  static String _webservicePluginFileUrl(String fileUrl) {
    // 只動 '?' 前面那一段：query 裡也可能出現 pluginfile.php。
    final queryAt = fileUrl.indexOf('?');
    final path = queryAt < 0 ? fileUrl : fileUrl.substring(0, queryAt);
    if (path.contains("/webservice/pluginfile.php")) return fileUrl;
    final at = path.indexOf("/pluginfile.php");
    if (at < 0) return fileUrl;
    final query = queryAt < 0 ? "" : fileUrl.substring(queryAt);
    return "${path.substring(0, at)}/webservice${path.substring(at)}$query";
  }

  /// 用 privatetoken 換一把一次性的 autologin 鑰匙（IP 綁定、60 秒後失效）。
  static const String autologinKeyFunction = "tool_mobile_get_autologin_key";

  static const String autologinScriptPath = "/admin/tool/mobile/autologin.php";

  /// 伺服器以不分大小寫的子字串比對認 Moodle App。
  static const String moodleAppUserAgentMarker = "MoodleMobile";

  /// 伺服器兩次取鑰匙的最短間隔（autologinmintimebetweenreq 預設 360 秒），
  /// 期間內一律回 lockout；站台改了設定這裡不會跟著變。
  static const Duration autologinMinInterval = Duration(minutes: 6);

  static const String autologinLockoutErrorcode =
      "autologinkeygenerationlockout";

  /// 這個 process 內再試也不會變好的錯誤。
  static const Set<String> autologinFatalErrorcodes = {
    "apprequired",
    "httpsrequired",
    "autologinnotallowedtoadmins",
    "invalidprivatetoken",
    "accessexception",
    "enablewsdescription",
  };

  /// 最近一次伺服器有記下時間戳的取鑰匙時間（成功或 lockout）。
  static DateTime? autologinLastKeyAt;

  static bool autologinDisabled = false;

  @visibleForTesting
  static DateTime Function() autologinClock = DateTime.now;

  static const Duration _defaultAutologinTimeout = Duration(seconds: 6);

  /// 開 WebView 前最多等這麼久；不能讓一次點擊卡到 Dio 的 100 秒 receiveTimeout。
  @visibleForTesting
  static Duration autologinTimeout = _defaultAutologinTimeout;

  /// 所有 wsfunction 的傳輸層；可替換是為了讓測試不必連網路。
  @visibleForTesting
  static Future<dynamic> Function(ConnectorParameter parameter) wsPost =
      _wsPost;

  /// 伺服器時鐘減裝置時鐘（秒）。作答倒數是拿伺服器寫下的 `timestarted` 加
  /// 時限，再跟現在相減——裝置時間錯幾分鐘，剩餘時間就少報或多報同樣多，
  /// 甚至會在 running 與 expired 之間翻面。Moodle 網頁的 `timer.js` 是從
  /// 伺服器算好的剩餘秒數起跳，這一條是它在 WS 上的替代品。
  static int serverClockSkewSeconds = 0;

  /// 依伺服器時鐘的現在。倒數與截止提示一律用它，不要直接讀 `DateTime.now()`。
  static DateTime serverNow() =>
      DateTime.now().add(Duration(seconds: serverClockSkewSeconds));

  /// 預設的傳輸層：順手記下 `Date` 標頭。走 Response 而不是
  /// [Connector.getJsonByPost] 只為了這一件事，回給呼叫端的仍然是 body。
  static Future<dynamic> _wsPost(ConnectorParameter parameter) async {
    final response = await Connector.getDataByPostResponse(parameter);
    _recordServerClock(response.headers.value('date'));
    return response.data;
  }

  /// `Date` 只到秒，而且還含一趟往返的時間，所以這個差是粗的——但它要修的是
  /// 分鐘級的裝置時間偏差，秒級的誤差無所謂。解析不出來就當作沒有這條線索。
  static void _recordServerClock(String? httpDate) {
    if (httpDate == null || httpDate.isEmpty) return;
    try {
      final server = HttpDate.parse(httpDate).millisecondsSinceEpoch ~/ 1000;
      serverClockSkewSeconds =
          server - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      // 標頭壞掉就沿用上一次的差；倒數退回本機時鐘不會比亂猜差。
    }
  }

  /// 上傳的傳輸層；可替換是為了讓測試不必連網路，同 [wsPost]。
  @visibleForTesting
  static Future<dynamic> Function(
    ConnectorParameter parameter, {
    required FormData formData,
    Duration? sendTimeout,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) uploadPost = Connector.postMultipart;

  /// 下載的傳輸層；可替換是為了讓測試不必連網路，同 [wsPost]。
  @visibleForTesting
  static Future<void> Function(
    String url,
    String savePath, {
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) fileDownloader = _downloadWithDio;

  static Future<void> _downloadWithDio(
    String url,
    String savePath, {
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) =>
      DioConnector.instance.download(url, (_) => savePath,
          cancelToken: cancelToken, progressCallback: onProgress);

  /// 測試用：把 autologin 的節流狀態與注入點全部還原。
  ///
  /// 名字已經跟不上內容了（它現在也重設 [wsPost] 與 [uploadPost]），改名要動
  /// 好幾個測試檔，留待後續處理。
  @visibleForTesting
  static void resetAutologinState() {
    autologinLastKeyAt = null;
    autologinDisabled = false;
    autologinClock = DateTime.now;
    autologinTimeout = _defaultAutologinTimeout;
    serverClockSkewSeconds = 0;
    wsPost = _wsPost;
    uploadPost = Connector.postMultipart;
    fileDownloader = _downloadWithDio;
  }

  static final String _moodleHost = Uri.parse(host).host;

  /// 自家站台的 host。給 util 層的純函式當比對基準：util 排在 connector 下面，
  /// 不可以反過來 import 這個檔案。
  static String get siteHost => _moodleHost;

  /// 取鑰匙的請求 User-Agent 必須含 MoodleMobile；只附記號，不假冒版本。
  static String moodleAppUserAgent(String base) =>
      "$base $moodleAppUserAgentMarker";

  /// 能交給 autologin.php 轉址的正規化目標，不能就回 null。urltogo 是
  /// PARAM_LOCALURL：非自家 https、帶 userinfo、非 ASCII 會被清空並靜靜轉到首頁。
  static String? autologinTarget(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != "https") return null;
    if (uri.host != _moodleHost) return null;
    if (uri.hasPort || uri.userInfo.isNotEmpty) return null;
    if (isAutologinScript(uri)) return null;
    return uri.toString();
  }

  static ({String key, String autologinUrl})? parseAutologinKey(dynamic data) {
    if (data is! Map) return null;
    final key = data["key"];
    final autologinUrl = data["autologinurl"];
    if (key is! String || key.isEmpty) return null;
    if (autologinUrl is! String || autologinUrl.isEmpty) return null;
    return (key: key, autologinUrl: autologinUrl);
  }

  /// autologinurl 不是自家 https host 就回 null：這個網址會帶著 cookie 開，
  /// 不能被回應內容指到別處。
  static String? buildAutologinUrl({
    required String autologinUrl,
    required String key,
    required String userId,
    required String target,
  }) {
    final base = Uri.tryParse(autologinUrl);
    if (base == null || base.scheme != "https" || base.host != _moodleHost) {
      return null;
    }
    if (key.isEmpty || userId.isEmpty || target.isEmpty) return null;
    return base.replace(queryParameters: {
      "userid": userId,
      "key": key,
      "urltogo": target,
    }).toString();
  }

  /// 把 Moodle 網址換成免登入的 autologin 網址。任何情況都不拋、不開畫面，
  /// 拿不到鑰匙就原樣回傳 [url]；非 Moodle 的網址不碰網路。
  static Future<String> autologinUrl(String url) async {
    final target = autologinTarget(url);
    if (target == null) return url;
    try {
      final wrapped =
          await _fetchAutologinUrl(target).timeout(autologinTimeout);
      return wrapped ?? url;
    } on TimeoutException {
      // 底下那個請求會自己跑完並記下時間戳；這裡不等它。
      Log.d("[autologin] 逾時，改以原網址開啟");
      return url;
    } catch (e, stack) {
      Log.eWithStack("[autologin] $e", stack);
      return url;
    }
  }

  /// 真正去換鑰匙；拿不到回 null，自己吞掉所有例外。
  static Future<String?> _fetchAutologinUrl(String target) async {
    if (wsToken == null || autologinDisabled) return null;
    final last = autologinLastKeyAt;
    if (last != null &&
        autologinClock().difference(last) < autologinMinInterval) {
      // 伺服器端這段時間內一定回 lockout，省掉這一趟。
      Log.d("[autologin] 距上次取鑰匙不足 "
          "${autologinMinInterval.inMinutes} 分鐘，略過");
      return null;
    }
    try {
      final entity = await Model.instance.getMoodleToken();
      final privateToken = entity?.privateToken ?? "";
      // privatetoken 必須是與目前 wsToken 同一列發下來的那一顆。
      if (entity == null || privateToken.isEmpty || entity.token != wsToken) {
        Log.d("[autologin] 沒有可用的 privatetoken，略過");
        return null;
      }
      final uid = await _ensureUserId();
      if (uid == null) return null;

      final result = await _callWs(
        autologinKeyFunction,
        {"privatetoken": privateToken},
        userAgent: moodleAppUserAgent(ConnectorParameter.presetUserAgent),
      );
      // 走到這裡伺服器已記下時間戳。
      autologinLastKeyAt = autologinClock();

      final parsed = parseAutologinKey(result);
      if (parsed == null) {
        Log.e("[autologin] 回應裡沒有 key / autologinurl");
        return null;
      }
      return buildAutologinUrl(
        autologinUrl: parsed.autologinUrl,
        key: parsed.key,
        userId: uid,
        target: target,
      );
    } on MoodleApiException catch (e) {
      if (e.errorcode == autologinLockoutErrorcode) {
        // 預期中的狀況（6 分鐘內開了第二頁），不是錯誤，也不送 onApiError。
        autologinLastKeyAt = autologinClock();
        Log.d("[autologin] 伺服器 lockout：$e");
        return null;
      }
      if (autologinFatalErrorcodes.contains(e.errorcode)) {
        autologinDisabled = true;
      }
      _reportFailure(autologinKeyFunction, e, StackTrace.current);
      return null;
    } catch (e, stack) {
      _reportFailure(autologinKeyFunction, e, stack);
      return null;
    }
  }

  /// 還原本機存下的 token。它只是 assumed 而非 verified：伺服器端可能早已
  /// 失效，第一個請求收到 invalidtoken 時由 `onApiError` 清掉並重登。
  static void restoreToken(MoodleTokenEntity token) {
    wsToken = token.token;
  }

  /// site_info 取得的 Moodle 使用者 id。process 級 static，換帳號必須清掉，
  /// 否則就是跨帳號洩漏；清除由 [wsToken] 的 setter 與 SessionCleaner 把關。
  static String? userId;

  /// 「HTTP 200 但其實是錯誤」的唯一判讀點，正常回應回 null。
  /// [treatWarningsAsError] 只給寫入路徑用：warnings[] 在讀取路徑上是常態。
  static MoodleApiException? moodleErrorOf(
    dynamic data, {
    required String wsFunction,
    bool treatWarningsAsError = false,
  }) {
    // 不是 Map 就不是 Moodle 的錯誤包（captive portal 的 HTML、正常的 List）。
    if (data is! Map) return null;

    if (data.containsKey("errorcode") || data.containsKey("exception")) {
      return MoodleApiException(
        wsFunction: wsFunction,
        errorcode: data["errorcode"]?.toString(),
        exception: data["exception"]?.toString(),
        message: data["message"]?.toString(),
        debugInfo: data["debuginfo"]?.toString(),
        siteFunctionVersion: siteInfo?.wsVersion(wsFunction),
      );
    }

    if (treatWarningsAsError) {
      final warnings = data["warnings"];
      if (warnings is List && warnings.isNotEmpty) {
        final first = warnings.first;
        return MoodleApiException(
          wsFunction: wsFunction,
          errorcode: first is Map ? first["warningcode"]?.toString() : null,
          message:
              first is Map ? first["message"]?.toString() : first.toString(),
          siteFunctionVersion: siteInfo?.wsVersion(wsFunction),
        );
      }
    }

    return null;
  }

  /// 寫入路徑第二個判讀點：`external_warnings` 是 `external_multiple_structure`，
  /// 所以 `mod_assign_save_submission` 與 `mod_assign_submit_for_grading` 回的是
  /// **裸陣列**而不是 `{warnings: [...]}`。[moodleErrorOf] 第一行就是
  /// `if (data is! Map) return null`，`treatWarningsAsError` 對它們完全無效——
  /// 照抄 toggleSetting 的寫法會 100% 把失敗當成功。成功是 `[]`。
  static MoodleApiException? writeWarningOf(
    dynamic result, {
    required String wsFunction,
  }) {
    if (result is! List || result.isEmpty) return null;
    final first = result.first;
    return MoodleApiException(
      wsFunction: wsFunction,
      errorcode: first is Map ? first["warningcode"]?.toString() : null,
      message: first is Map ? first["message"]?.toString() : first.toString(),
      siteFunctionVersion: siteInfo?.wsVersion(wsFunction),
    );
  }

  /// 寫入路徑第三個判讀點：形狀本身就是契約。`external_warnings` 只可能回
  /// `[]` 或 `[{...}]`，所以**不是 List 就是這一趟根本沒到 Moodle**——
  /// captive portal 的 HTML、代理的錯誤頁、`validateStatus` 放行的 500 都是
  /// String 或 null，[moodleErrorOf] 與 [writeWarningOf] 兩個都會放行。
  /// 讀取路徑可以 fail-open（它有快取可以退），寫入路徑不行。
  static MoodleApiException? writeShapeErrorOf(
    dynamic result, {
    required String wsFunction,
  }) {
    if (result is List) return null;
    return MoodleApiException(
      wsFunction: wsFunction,
      errorcode: "badresponse",
      message: "$wsFunction 回的不是 warnings 陣列（${result.runtimeType}）",
      siteFunctionVersion: siteInfo?.wsVersion(wsFunction),
    );
  }

  /// 同 [writeShapeErrorOf]，但問的是回 `external_single_structure` 的那兩支
  /// （remove / start）：它們的合法回應是 Map，不是 Map 就是這一趟根本沒到
  /// Moodle。對稱要補齊，否則 captive portal 的 HTML 會一路通過
  /// [moodleErrorOf]（`data is! Map` 直接放行）與 `treatWarningsAsError`。
  static MoodleApiException? writeObjectShapeErrorOf(
    dynamic result, {
    required String wsFunction,
  }) {
    if (result is Map) return null;
    return MoodleApiException(
      wsFunction: wsFunction,
      errorcode: "badresponse",
      message: "$wsFunction 回的不是物件（${result.runtimeType}）",
      siteFunctionVersion: siteInfo?.wsVersion(wsFunction),
    );
  }

  /// 不在 site_info `functions[]` 裡的 function 送出去必定回 accessexception，
  /// 這裡先擋下省一次往返。清單還沒載入或是空的一律放行（fail-open）。
  static MoodleApiException? wsFunctionBlocked(String wsFunction) {
    // site_info 是清單本身的來源，擋掉它等於再也拿不到清單，是死結。
    if (wsFunction == siteInfoFunction) return null;

    final profile = siteInfo;
    if (profile == null || !profile.knowsWsFunctions) return null;
    if (profile.wsAvailable(wsFunction)) return null;

    return MoodleApiException(
      wsFunction: wsFunction,
      errorcode: "accessexception",
      message: "站台未對這個 token 開放 $wsFunction"
          "（site_info 的 functions[] 沒有列出），已在送出前跳過",
      skippedBeforeRequest: true,
    );
  }

  /// 所有 wsfunction 的唯一出口，失敗一律拋 [MoodleApiException]。
  /// [userAgent] 只給這一個請求用（autologin 要帶 MoodleMobile 記號）。
  static Future<dynamic> _callWs(
    String wsFunction,
    Map<String, dynamic> data, {
    bool treatWarningsAsError = false,
    String? userAgent,
  }) async {
    final blocked = wsFunctionBlocked(wsFunction);
    if (blocked != null) throw blocked;

    final parameter = ConnectorParameter(_webAPIUrl);
    if (userAgent != null) parameter.userAgent = userAgent;
    parameter.data = {
      "moodlewsrestformat": "json",
      "wsfunction": wsFunction,
      "wstoken": wsToken,
      ...data,
    };
    final result = await wsPost(parameter);
    final error = moodleErrorOf(
      result,
      wsFunction: wsFunction,
      treatWarningsAsError: treatWarningsAsError,
    );
    if (error != null) throw error;
    return result;
  }

  /// 各個 getter 的 catch 共用收尾。[MoodleApiException] 不用 eWithStack：
  /// 那會送進 Crashlytics，而 token 過期、站台維護不該被當成當機回報。
  static void _reportFailure(String wsFunction, Object e, StackTrace stack) {
    if (e is MoodleApiException) {
      Log.e(e.toString());
      onApiError?.call(e);
      return;
    }
    Log.eWithStack("$wsFunction: $e", stack);
  }

  /// 解析失敗只是這次快取不到，刻意吞掉：呼叫端問的是「token 還能不能用」。
  static void _cacheSiteInfo(dynamic data) {
    if (data is! Map) return;
    try {
      siteInfo = MoodleProfileEntity.fromJson(Map<String, dynamic>.from(data));
    } catch (e, stack) {
      Log.eWithStack("cache site info: $e", stack);
    }
  }

  /// 取得 userId，需要時才打 site_info；失敗回 null 或拋 [MoodleApiException]。
  static Future<String?> _ensureUserId() async {
    final cached = userId;
    if (cached != null) return cached;
    final result = await _callWs(siteInfoFunction, const {});
    if (result is! Map || result["userid"] == null) {
      // 不要無聲失敗：回 null 之後上游也跟著回 null，錯誤原因整條線消失。
      _reportFailure(
        siteInfoFunction,
        MoodleApiException(
          wsFunction: siteInfoFunction,
          message: 'site_info 回應裡沒有 userid',
        ),
        StackTrace.current,
      );
      return null;
    }
    _cacheSiteInfo(result);
    return userId = result["userid"].toString();
  }

  static Future<MoodleWebApiConnectorStatus> login(
      String account, String password) async {
    try {
      final tokenData = await InteractiveLoginGateway.instance
          .signInMoodle(account: account, password: password);
      if (tokenData == null) {
        return MoodleWebApiConnectorStatus.loginFail;
      }

      wsToken = tokenData.token;

      await Model.instance.setMoodleToken(tokenData);

      return MoodleWebApiConnectorStatus.loginSuccess;
    } catch (e, stack) {
      Log.eWithStack(e, stack);
    }

    return MoodleWebApiConnectorStatus.loginFail;
  }

  /// 檢查 wsToken 在伺服器端是否仍有效。它在 App 啟動路徑上，例外逸出會讓
  /// 主畫面永遠停在載入中，所以一律吞掉回 false。
  static Future<bool> isMoodleTokenAvailable() async {
    if (wsToken == null) {
      return false;
    }

    try {
      // 不要印 result：site_info 帶 userid、fullname 與 userprivateaccesskey。
      final result = await _callWs(siteInfoFunction, const {});
      // 不要硬轉型：captive portal 會回 200 加一段 HTML，轉型會拋 TypeError。
      if (result is! Map) return false;
      // 順手記下 userid 與 function 清單，之後的頁面就不必再各打一次 site_info。
      if (result["userid"] != null) userId = result["userid"].toString();
      _cacheSiteInfo(result);
      return true;
    } catch (e, stack) {
      _reportFailure(siteInfoFunction, e, stack);
      return false;
    }
  }

  /// 課程的 Moodle 內部 id。缺席時回 null，不要用 `course["id"].toString()`：
  /// 那會產生字面上的 "null" 並被上層當成有效 id 快取起來。
  static String? _courseKeyOf(Map course) {
    final id = course["id"];
    if (id == null) return null;
    return id.toString();
  }

  /// [_getUsersCourses] 的短期記憶：課號對照、學期課號清單、目前學期三者會在
  /// 同一次課表更新裡接連呼叫。換 token 時由 wsToken 的 setter 清掉。
  static List<dynamic>? _usersCoursesCache;

  /// wsToken 的 setter 只在值真的改變時清，所以登出與測試重設要明確呼叫這個。
  static void clearCoursesCache() => _usersCoursesCache = null;

  /// 一次拿回這個帳號的全部課程（含已結束的歷史學期），每門帶 idnumber、
  /// startdate、enddate。拿不到 userid 回 null；其他失敗照常拋。
  static Future<List<dynamic>?> _getUsersCourses({bool refresh = false}) async {
    if (!refresh && _usersCoursesCache != null) return _usersCoursesCache;
    final uid = await _ensureUserId();
    if (uid == null) return null;

    final result = await _callWs(enrolledCoursesFunction, {
      "moodlewssettingfilter": "true",
      "moodlewssettingfileurl": "true",
      "userid": uid,
      // 人數多的課程算這個統計會多花好幾秒，而這裡用不到。
      "returnusercount": "0",
    });
    return _usersCoursesCache = result as List;
  }

  /// idnumber 的前綴長度：`<學年3碼><學期1碼>`（例如 1141、114H）。
  static const int semesterPrefixLength = 4;

  /// 去掉學年學期前綴之後的課號。長度不夠時回 null。
  static String? _courseIdOf(String idnumber) =>
      idnumber.length > semesterPrefixLength
          ? idnumber.substring(semesterPrefixLength)
          : null;

  /// 以 idnumber 為準找出 Moodle 內部課程 id，找不到回 null。fullname 只是
  /// fallback：課名裡剛好含有課號就會配到錯的課、開出別人的成績與名單。
  static String? matchCourseId(List<dynamic> courses, String courseId) {
    if (courseId.isEmpty) return null;
    for (final course in courses) {
      if (course is! Map) continue;
      final idnumber = course["idnumber"];
      if (idnumber is! String || idnumber.isEmpty) continue;
      if (idnumber == courseId || _courseIdOf(idnumber) == courseId) {
        final id = _courseKeyOf(course);
        if (id != null) return id;
      }
    }
    for (final course in courses) {
      if (course is! Map) continue;
      final fullname = course["fullname"];
      if (fullname is String && fullname.contains(courseId)) {
        final id = _courseKeyOf(course);
        if (id != null) return id;
      }
    }
    return null;
  }

  static Future<String?> getCourseUrl(String courseId) async {
    try {
      final courses = await _getUsersCourses();
      if (courses == null) return null;
      return matchCourseId(courses, courseId);
    } catch (e, stack) {
      _reportFailure(enrolledCoursesFunction, e, stack);
      return null;
    }
  }

  /// 取得課程目錄。`core_course_get_contents` 會把整門課的單元與檔案中繼資料
  /// 一次送回，是最重的呼叫；只找特定模組時務必用 [modName] 收窄。
  static Future<List<MoodleCoreCourseGetContents>?> getCourseDirectory(
      String courseId,
      {String? modName}) async {
    const wsFunction = "core_course_get_contents";
    try {
      final result = await _callWs(wsFunction, {
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "courseid": courseId,
        if (modName != null) ...{
          "options[0][name]": "modname",
          "options[0][value]": modName,
        },
      });
      List<MoodleCoreCourseGetContents> v = (result as List)
          .map((e) => MoodleCoreCourseGetContents.fromJson(e))
          .toList();
      for (var i in v) {
        for (var j in i.modules) {
          j.name = HtmlUtils.clean(j.name);
        }
      }
      return v;
    } catch (e, stack) {
      _reportFailure(wsFunction, e, stack);
      return null;
    }
  }

  /// 這門課的公告討論串清單。找不到公告區時回 `forumFound: false` 的空清單，
  /// 那不是失敗；真的抓不到才回 null。
  static Future<MoodleModForumGetForumDiscussions?> getCourseAnnouncement(
      String id) async {
    try {
      final forumId = await _findAnnouncementForumId(id);
      // 沒有公告區不是錯誤：有些課真的沒開，畫面要說清楚而不是叫人重試。
      if (forumId == null) {
        return MoodleModForumGetForumDiscussions(forumFound: false);
      }
      final result = await _callWs(forumDiscussionsFunction, {
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "forumid": forumId.toString(),
        "page": 0,
        "perpage": announcementPerPage,
        "sortorder": 1,
        "groupid": 0,
      });
      final parsed = announcementsOf(result);
      // 合成欄位：公告那條路的 forum id 本來只活在 _findAnnouncementForumId
      // 裡面，而回覆要附件就必須知道它。
      if (parsed != null) parsed.forumId = forumId;
      return parsed;
    } catch (e, stack) {
      _reportFailure(forumDiscussionsFunction, e, stack);
      return null;
    }
  }

  /// 公告區的 forum instance id。找到回 id；「這門課沒有公告區」回 null；
  /// 兩條路都問不出來就拋，由呼叫端當成取得失敗。
  static Future<int?> _findAnnouncementForumId(String courseId) async {
    Object? forumsError;
    try {
      final forums = await _fetchForums(courseId);
      if (forums != null) return pickAnnouncementForum(forums)?.id;
    } catch (e) {
      // 這裡吞掉是為了「站台沒開這支 function」那條名稱比對的退路，但 token
      // 過期、站台維護也會走到；原因留著，退路也失敗時要照原樣往上拋。
      Log.d("[announcement] $forumsByCoursesFunction 不可用，改用名稱比對：$e");
      forumsError = e;
    }
    final contents = await getCourseDirectory(courseId, modName: "forum");
    if (contents == null) {
      // 換成 Exception 會讓 MoodleApiException 被當成當機送進 Crashlytics。
      throw forumsError ?? Exception("course contents is null");
    }
    return legacyAnnouncementForumId(contents);
  }

  /// 回的是 forum 陣列本身，不是 `{forums: []}`；形狀不對回 null。
  static List<MoodleForum>? forumsOf(dynamic result) {
    if (result is! List) return null;
    return [
      for (final e in result)
        if (e is Map) MoodleForum.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  /// 這門課的討論區清單。失敗回 null（附件政策問不到就是「不給附件」）。
  /// 與公告那條路共用同一趟參數，只差這裡吞掉例外。
  static Future<List<MoodleForum>?> getForums(String courseId) async {
    try {
      return await _fetchForums(courseId);
    } catch (e, stack) {
      _reportFailure(forumsByCoursesFunction, e, stack);
      return null;
    }
  }

  static Future<List<MoodleForum>?> _fetchForums(String courseId) async =>
      forumsOf(await _callWs(forumsByCoursesFunction, {
        "moodlewssettingfilter": "true",
        "courseids[0]": courseId,
      }));

  static const String newsForumType = 'news';

  /// 公告區的判斷。type 是結構欄位，課程改課名、改討論區名稱都不影響它。
  static MoodleForum? pickAnnouncementForum(List<MoodleForum> forums) {
    for (final f in forums) {
      if (f.type == newsForumType) return f;
    }
    // 退路：站台把公告區改成一般討論區時只剩名稱可以認。
    for (final f in forums) {
      if (looksLikeAnnouncementName(f.name)) return f;
    }
    return null;
  }

  /// 公告後來改名成「課程公佈欄」，英文站台是 Announcements / News forum。
  static const List<String> announcementNameHints = [
    '公告',
    '課程公佈欄',
    'Announcements',
    'News forum',
  ];

  static bool looksLikeAnnouncementName(String name) =>
      announcementNameHints.any(name.contains);

  /// 站台沒開 get_forums_by_courses 時，照舊從整門課的內容比對名稱。
  static int? legacyAnnouncementForumId(
      List<MoodleCoreCourseGetContents> contents) {
    for (final section in contents) {
      if (!section.name.contains("一般")) continue;
      for (final m in section.modules) {
        if (looksLikeAnnouncementName(m.name)) return m.instance;
      }
    }
    return null;
  }

  /// 形狀不對回 null。`name` 與 `subject` 都是 format_string 過的，在這裡還原
  /// 成純文字（清單列、AppBar 標題與抓不到回覆時的退路子標題都是純文字 sink）。
  static MoodleModForumGetForumDiscussions? announcementsOf(dynamic result) {
    if (result is! Map) return null;
    final parsed = MoodleModForumGetForumDiscussions.fromJson(
        Map<String, dynamic>.from(result));
    for (final d in parsed.discussions) {
      d.name = HtmlUtils.clean(d.name);
      d.subject = HtmlUtils.clean(d.subject);
    }
    return parsed;
  }

  /// 一個討論串的全部貼文。`sortby=created&sortdirection=ASC` 讓第一篇一定在
  /// 最前面；`includeinlineattachments` 一定要開，否則 message 裡的
  /// `@@PLUGINFILE@@` 沒有對應的檔案可以換（post_exporter 不跑 format_text）。
  static Future<List<MoodleForumPost>?> getDiscussionPosts(
      int discussionId) async {
    try {
      return discussionPostsOf(await _callWs(discussionPostsFunction, {
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "discussionid": discussionId.toString(),
        "sortby": "created",
        "sortdirection": "ASC",
        "includeinlineattachments": "1",
      }));
    } catch (e, stack) {
      _reportFailure(discussionPostsFunction, e, stack);
      return null;
    }
  }

  /// 形狀不對或空清單回 null（討論串一定至少有一篇，空的代表這次沒問到）。
  /// subject 進子標題（純文字 sink）所以還原實體；message 的 `@@PLUGINFILE@@`
  /// 也在這裡換掉，快取存的就是可以直接算繪的 HTML。
  static List<MoodleForumPost>? discussionPostsOf(dynamic result) {
    if (result is! Map) return null;
    final parsed = MoodleModForumGetDiscussionPosts.fromJson(
        Map<String, dynamic>.from(result));
    if (parsed.posts.isEmpty) return null;
    for (final p in parsed.posts) {
      _normalizePost(p);
    }
    return parsed.posts;
  }

  /// 網路邊界上的正規化，讀取與寫入兩條路共用一份。轉換必須恰好發生一次：
  /// 轉完把 `messageformat` 蓋成 HTML，快取讀回來時才不會再轉一次。
  static void _normalizePost(MoodleForumPost p) {
    p.subject = HtmlUtils.clean(p.subject);
    // replysubject 是回覆時要送回去的標題（PARAM_TEXT），純文字 sink。
    p.replysubject = HtmlUtils.clean(p.replysubject);
    p.message = MoodleForumUtils.resolveInlinePluginFiles(
        p.message, p.messageinlinefiles);
    p.message =
        MoodleForumUtils.messageToDisplayHtml(p.message, p.messageformat);
    p.messageformat = MoodleForumUtils.formatHtml;
  }

  /// 一般討論區的主題清單。參數與公告那一支完全相同，只差 forumId 是呼叫端
  /// 給的；還原實體同樣共用 [announcementsOf]。
  static Future<List<Discussions>?> getForumDiscussions(int forumId) async {
    try {
      final result = await _callWs(forumDiscussionsFunction, {
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "forumid": forumId.toString(),
        "page": 0,
        "perpage": announcementPerPage,
        "sortorder": 1,
        "groupid": 0,
      });
      return announcementsOf(result)?.discussions;
    } catch (e, stack) {
      _reportFailure(forumDiscussionsFunction, e, stack);
      return null;
    }
  }

  /// 形狀不對回 null。每一格都是 VALUE_OPTIONAL，缺席就是 null＝不知道。
  @visibleForTesting
  static MoodleForumAccess? accessOf(dynamic result) {
    if (result is! Map) return null;
    return MoodleForumAccess.fromJson(Map<String, dynamic>.from(result));
  }

  /// 這個討論區的 capability 快照。失敗回 null——附件上「不知道」等於「不給」。
  static Future<MoodleForumAccess?> getForumAccess(int forumId) async {
    try {
      return accessOf(await _callWs(forumAccessInformationFunction, {
        "forumid": forumId.toString(),
      }));
    } catch (e, stack) {
      _reportFailure(forumAccessInformationFunction, e, stack);
      return null;
    }
  }

  /// 站台有沒有對這個 token 開放「回覆」。site_info 還沒載入時 fail-open，
  /// 態度與 [wsFunctionBlocked] 一致：第一次送出才會拿到 accessexception。
  static bool get canPostToForum =>
      wsFunctionBlocked(addDiscussionPostFunction) == null;

  /// 站台有沒有開放編輯。關掉時不畫編輯，選單只剩刪除。
  static bool get canEditForumPost =>
      wsFunctionBlocked(updateDiscussionPostFunction) == null;

  static bool get canDeleteForumPost =>
      wsFunctionBlocked(deletePostFunction) == null;

  /// 關掉時**原本沒有附件的貼文照樣可以編輯**（附件區收起來），有附件的那些
  /// 連編輯入口都不給：那時只剩「不送 `attachmentsid`」一條路，而那會把
  /// `forum_posts.attachment` 清成空字串——檔案還在，主題清單的迴紋針不見。
  static bool get canPrepareForumDraftArea =>
      wsFunctionBlocked(prepareDraftAreaFunction) == null;

  /// 關掉時編輯入口整個收起來：拿不到原文與新鮮的 capabilities，硬編會用過期
  /// 的快照覆蓋掉伺服器上的東西。
  static bool get canReadForumPost =>
      wsFunctionBlocked(discussionPostFunction) == null;

  /// `post` 欄位 → 已正規化的貼文。缺席或形狀不對回 null；呼叫端必須把 null
  /// 當成失敗，**不可以**當成「送出成功但沒東西可畫」。
  @visibleForTesting
  static MoodleForumPost? addedPostOf(dynamic result) {
    if (result is! Map) return null;
    final post = result["post"];
    if (post is! Map) return null;
    final parsed = MoodleForumPost.fromJson(Map<String, dynamic>.from(post));
    _normalizePost(parsed);
    return parsed;
  }

  /// 回覆一篇貼文，回伺服器算好的新貼文。
  ///
  /// [postId] 是**貼文** id（第一篇也算），不是討論串 id。
  ///
  /// `messageformat=2` 加 `topreferredformat=1`：前者宣告送出去的是純文字，
  /// 後者讓伺服器在存檔前依站台預設編輯器轉成 HTML。少了前者伺服器會把內容
  /// 當 HTML 解析（VALUE_DEFAULT 是 FORMAT_HTML），換行與 `<` 都會不見。
  /// `discussionsubscribe` / `private` / `attachmentsid` 一律不送：訂閱行為
  /// 要跟網頁版一致，另外兩個不在範圍內。
  ///
  /// `treatWarningsAsError` 照寫（寫入路徑的慣例），但這一支的 `$warnings`
  /// 在伺服器端初始化後從不 append，真正的失敗訊號是例外與「回不出 post」。
  ///
  /// 沒有冪等鍵：送出後連線中斷時，伺服器可能已經寫入而客戶端看到失敗。
  /// 這件事在客戶端無解，所以失敗文案寫「送出失敗」而不是「請再試一次」，
  /// 重新進頁面時的重新載入會顯示到底哪一則真的發出去了。
  /// [attachmentsId] 是 `upload.php` 開出來的 draft 區 itemid，**不送等於
  /// 沒有附件**（`forum_add_attachment()` 開頭是
  /// `if (empty($post->attachments)) return true;`）。送了也不保證收得下：
  /// 沒有 `mod/forum:createattachment` 時伺服器把這個值**靜靜改成 0**、不報錯，
  /// 所以呼叫端必須事後比對回應裡的 `post.attachments`。
  static Future<MoodleForumPost> addDiscussionPost({
    required int postId,
    required String subject,
    required String message,
    int? attachmentsId,
  }) async {
    try {
      final result = await _callWs(
        addDiscussionPostFunction,
        {
          "postid": postId.toString(),
          "subject": subject,
          "message": message,
          "messageformat": forumMessageFormatPlain,
          "options[0][name]": "topreferredformat",
          "options[0][value]": "1",
          if (attachmentsId != null) ...{
            "options[1][name]": "attachmentsid",
            "options[1][value]": attachmentsId.toString(),
          },
        },
        treatWarningsAsError: true,
      );
      final post = addedPostOf(result);
      if (post == null) {
        throw MoodleApiException(
          wsFunction: addDiscussionPostFunction,
          errorcode: "couldnotadd",
          message: "回應裡沒有可解析的 post，無法確認這則回覆真的送出去了",
        );
      }
      return post;
    } catch (e, stack) {
      _reportAndRethrow(addDiscussionPostFunction, e, stack);
    }
  }

  /// `mod_forum_get_discussion_post` 的 `post` → 編輯頁要的那幾格。
  ///
  /// **刻意不回 [MoodleForumPost]**：這一支回的是資料庫裡的**原文**
  /// （post_exporter 的 `get_message()` 不跑 `format_text`，`@@PLUGINFILE@@`
  /// 原封不動），一旦包成 `MoodleForumPost` 就會有人拿去 [_normalizePost] 或
  /// 寫進 `cache_moodle_forum_posts`，那會把原文換成算繪好的 HTML 再存起來，
  /// 之後的編輯就是拿算繪結果去覆蓋伺服器的原文。用一個不同的型別讓這件事
  /// 在型別上不可能發生。
  @visibleForTesting
  static ForumPostEdit? postForEditOf(dynamic result) {
    if (result is! Map) return null;
    final post = result["post"];
    if (post is! Map) return null;
    final id = post["id"];
    if (id is! num) return null;
    final capabilities = post["capabilities"];
    final attachments = post["attachments"];
    return (
      id: id.toInt(),
      subject: HtmlUtils.clean(post["subject"]?.toString() ?? ""),
      rawMessage: post["message"]?.toString() ?? "",
      rawFormat: switch (post["messageformat"]) {
        final num n => n.toInt(),
        _ => MoodleForumUtils.formatHtml,
      },
      canEdit: capabilities is Map && capabilities["edit"] == true,
      attachments: [
        if (attachments is List)
          for (final a in attachments)
            if (a is Map)
              MoodleForumFile.fromJson(Map<String, dynamic>.from(a)),
      ],
    );
  }

  /// 按下編輯時打的那一趟：拿新鮮的 `capabilities.edit` 與原文。
  ///
  /// **這一份回應不可以走 [_normalizePost]、也不可以進快取。**
  /// 不帶 `includeinlineattachments`，所以 `messageinlinefiles` 必定是空的
  /// ——不要拿它去解 `@@PLUGINFILE@@`。
  static Future<ForumPostEdit?> getPostForEdit(int postId) async {
    try {
      return postForEditOf(await _callWs(discussionPostFunction, {
        // 編輯要的是資料庫原文，不是算繪結果：`filter` 會把 filter plugin
        // （多媒體、詞彙連結）的產物寫死進去，`fileurl` 會把
        // `@@PLUGINFILE@@` 換成絕對網址——兩者原樣送回伺服器就是永久污染。
        // post_exporter 本來就可能不跑 `format_text`；真是那樣這三個設定是
        // no-op，不是的話正好修掉，兩種情況下都正確。
        "moodlewssettingraw": "true",
        "moodlewssettingfilter": "false",
        "moodlewssettingfileurl": "false",
        "postid": postId.toString(),
      }));
    } catch (e, stack) {
      _reportFailure(discussionPostFunction, e, stack);
      return null;
    }
  }

  /// 把這篇貼文現有的附件整批複製進使用者的 draft 區，回那個 draft 區。
  ///
  /// **空的 [filesToKeep] ＝全部保留，不是全部刪掉**（伺服器只在名單非空時
  /// 才刪掉不在名單上的）。要移除某個既有附件，就把要留下的列出來。
  ///
  /// [area] 只能是 [forumDraftAreaAttachment] 或 [forumDraftAreaPost]，其他值
  /// 丟 `invalid_parameter_exception`。兩者是完全不同的檔案區：`post` 種的是
  /// **內嵌圖片**，而且只有它會在 `messagetext` 回貼文原文＋draft 網址前綴。
  /// 對 `post` 區送非空的 [filesToKeep] 會把要保護的圖片刪掉，呼叫端一律送空。
  ///
  /// 它會先驗 `can_edit_post()`，不過就丟 **`noviewdiscussionspermission`**
  /// ——那個 errorcode 會騙人，字面是「沒有檢視權限」，實際意思是「你不能
  /// 編輯這一篇」（多半是超過 `$CFG->maxeditingtime`）。
  static Future<MoodleForumDraftArea> prepareForumDraftArea({
    required int postId,
    String area = forumDraftAreaAttachment,
    List<({String filename, String filepath})> filesToKeep = const [],
  }) async {
    try {
      final result = await _callWs(
        prepareDraftAreaFunction,
        {
          "postid": postId.toString(),
          "area": area,
          "draftitemid": "0",
          for (var i = 0; i < filesToKeep.length; i++) ...{
            "filestokeep[$i][filename]": filesToKeep[i].filename,
            "filestokeep[$i][filepath]": filesToKeep[i].filepath,
          },
        },
        treatWarningsAsError: true,
      );
      final parsed = draftAreaOf(result);
      // 證明不了 draft 區存在就不能拿它去覆蓋附件——送一個假的 itemid 進
      // update_discussion_post 會把既有附件同步成空的。
      if (parsed == null) {
        throw MoodleApiException(
          wsFunction: prepareDraftAreaFunction,
          errorcode: "couldnotadd",
          message: "回應裡沒有可用的 draftitemid，無法確認 draft 區真的開好了",
        );
      }
      return parsed;
    } catch (e, stack) {
      _reportAndRethrow(prepareDraftAreaFunction, e, stack);
    }
  }

  /// 形狀不對、或 `draftitemid` 不是正整數時回 null。
  @visibleForTesting
  static MoodleForumDraftArea? draftAreaOf(dynamic result) {
    if (result is! Map) return null;
    final raw = result["draftitemid"];
    final itemId = raw is num ? raw.toInt() : int.tryParse("$raw");
    if (itemId == null || itemId <= 0) return null;
    final files = result["files"];
    return MoodleForumDraftArea(
      draftitemid: itemId,
      files: [
        if (files is List)
          for (final f in files)
            if (f is Map)
              MoodleForumDraftFile.fromJson(Map<String, dynamic>.from(f)),
      ],
      maxbytes:
          MoodleForumDraftArea.intOptionOf(result["areaoptions"], "maxbytes"),
      maxfiles:
          MoodleForumDraftArea.intOptionOf(result["areaoptions"], "maxfiles"),
      // `area == 'attachment'` 時伺服器送回 null，那時它就是空字串。
      messagetext: result["messagetext"] is String
          ? result["messagetext"] as String
          : "",
    );
  }

  /// 編輯自己的貼文。
  ///
  /// 三件一定要記住的事：
  /// 1. **不可以送 `topreferredformat`。** 這一支借用
  ///    `add_discussion_post_parameters()` 做 validate_parameters，但選項白名單
  ///    在函式本體，只認 `pinned` / `discussionsubscribe` / `inlineattachmentsid`
  ///    / `attachmentsid`——送了會回 `errorinvalidparam`。從回覆那一段複製貼上
  ///    是最自然的寫法，而且只有真的按下編輯才會炸。
  /// 2. **空 subject／空 message ＝不改，不是清空**，然後照樣回 `status: true`。
  ///    呼叫端要先擋掉空內容，否則使用者會看到「已更新」而東西一個字沒變。
  /// 3. **不送 [attachmentsId] ＝既有附件原封不動**（`IGNORE_FILE_MERGE`），
  ///    但 `forum_update_post()` 最後無條件呼叫 `forum_add_attachment()`，
  ///    而 `empty(-1) === false` 過不了那個 early return，於是
  ///    `file_get_draft_area_info(-1)` 回 filecount 0 →
  ///    `$DB->set_field('forum_posts','attachment','')`：**貼文的 attachment
  ///    旗標會被清成空字串**，檔案還在，但主題清單的迴紋針會憑空消失。
  ///    所以「原本有附件」或「使用者新加了附件」時一律要送。
  /// 4. **[messageFormat] 一定要帶原文的 format 回去。** 這一支不吃
  ///    `topreferredformat`（見 1.），寫死送 FORMAT_PLAIN 會把一篇
  ///    FORMAT_HTML 貼文永久改成純文字，而且救不回來。
  static Future<void> updateDiscussionPost({
    required int postId,
    required String subject,
    required String message,
    required int messageFormat,
    int? attachmentsId,
    int? inlineAttachmentsId,
  }) async {
    // **送 0 會把貼文裡的內嵌圖片全部刪光。** 伺服器端是
    // `clean_param($option['value'], PARAM_INT)` 之後 `isset()`，而 isset(0)
    // 是 true，於是 itemid 變成 0 → draft 區是空的 →
    // `file_save_draft_area_files()` 那個 `if (!isset($newhashes[$oldhash]))
    // { $oldfile->delete(); }` 迴圈把每一張圖都刪掉。
    //
    // 這裡丟例外而不是靜靜改成 null：改成 null 等於退回 IGNORE_FILE_MERGE，
    // 那會把我們送出去的 draftfile 絕對網址原樣存進資料庫，圖片一樣壞掉，
    // 只是要等到 draft 區被 cron 清掉才看得出來。
    if (inlineAttachmentsId != null && inlineAttachmentsId <= 0) {
      throw ArgumentError.value(inlineAttachmentsId, 'inlineAttachmentsId',
          '必須是 prepare_draft_area_for_post(area: post) 回傳的正整數');
    }
    // 索引要連號：只送 inlineattachmentsid 時它必須是 options[0]。
    final options = <(String, String)>[
      if (attachmentsId != null) ("attachmentsid", attachmentsId.toString()),
      if (inlineAttachmentsId != null)
        ("inlineattachmentsid", inlineAttachmentsId.toString()),
    ];
    try {
      final result = await _callWs(
        updateDiscussionPostFunction,
        {
          "postid": postId.toString(),
          "subject": subject,
          "message": message,
          "messageformat": messageFormat.toString(),
          for (final (i, o) in options.indexed) ...{
            "options[$i][name]": o.$1,
            "options[$i][value]": o.$2,
          },
        },
        treatWarningsAsError: true,
      );
      _requireWriteStatus(result, updateDiscussionPostFunction);
    } catch (e, stack) {
      _reportAndRethrow(updateDiscussionPostFunction, e, stack);
    }
  }

  /// 刪除一篇貼文。**沒有父貼文（＝討論串主文）時伺服器會刪掉整串**
  /// （`forum_delete_discussion`），所以確認框必須講清楚。
  ///
  /// 刪掉主文之後**不可以**再打 `mod_forum_get_discussion_posts`：那一支的
  /// `$discussionvault->get_from_id()` 沒有 null 檢查，下一行
  /// `$discussion->get_forum_id()` 會丟 PHP Error（回應裡沒有 forum errorcode），
  /// 看起來就像「刪除失敗」，而其實已經刪掉了。
  static Future<void> deleteForumPost(int postId) async {
    try {
      final result = await _callWs(
        deletePostFunction,
        {"postid": postId.toString()},
        treatWarningsAsError: true,
      );
      _requireWriteStatus(result, deletePostFunction);
    } catch (e, stack) {
      _reportAndRethrow(deletePostFunction, e, stack);
    }
  }

  /// `status != true` 一律當失敗。實務上不可達（`forum_update_post()` 最後
  /// 無條件回 true），但證明不了寫入發生過就是失敗。
  static void _requireWriteStatus(dynamic result, String wsFunction) {
    if (MoodleForumWriteStatus.of(result)?.status == true) return;
    throw MoodleApiException(
      wsFunction: wsFunction,
      errorcode: "badresponse",
      message: "$wsFunction 沒有回 status: true，無法確認寫入真的發生過",
    );
  }

  /// manager、coursecreator 是站台層級角色、不是這門課的老師，刻意不列：
  /// 這份名單的用途是找同學，寧可多顯示一個人也不要藏起真的同學。
  static const Set<String> teacherRoleShortNames = {
    'editingteacher',
    'teacher',
  };

  /// 以 roles 判斷，不要退回比對名字裡有沒有「老師」。roles 為空時回 true：
  /// 規格沒保證拿得到，全部藏起來會讓名單變空而上層對空名單直接報錯。
  static bool isCourseMember(MoodleCoreEnrolGetUsers user) {
    if (user.roles.isEmpty) return true;
    return !user.roles
        .any((role) => teacherRoleShortNames.contains(role.shortname));
  }

  static Future<List<MoodleCoreEnrolGetUsers>?> getMember(String id) async {
    const wsFunction = "core_enrol_get_enrolled_users";
    List<MoodleCoreEnrolGetUsers> userinfo = [];
    try {
      final result = await _callWs(wsFunction, {
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "courseid": id,
        "options[0][name]": "limitfrom",
        "options[0][value]": "0",
        "options[1][name]": "limitnumber",
        "options[1][value]": "0",
        "options[2][name]": "sortby",
        "options[2][value]": "siteorder",
      });
      for (var i in (result as List)) {
        var user = MoodleCoreEnrolGetUsers.fromJson(i as Map<String, dynamic>);
        if (isCourseMember(user)) userinfo.add(user);
      }
      return userinfo;
    } catch (e, stack) {
      _reportFailure(wsFunction, e, stack);
      return null;
    }
  }

  /// 某學期的課號清單。失敗一律 null，不能回空清單：空清單會被上游當成
  /// 「這學期真的沒有課」而覆蓋掉磁碟上正確的快取。歷史學期只有
  /// `core_enrol_get_users_courses` 撈得到，timeline 端點只回 inprogress。
  static Future<List<String>?> getCourseIds(SemesterJson semester) async {
    try {
      final courses = await _getUsersCourses();
      if (courses == null) return null;
      return courseIdsOfSemester(courses, semester);
    } catch (e, stack) {
      _reportFailure(enrolledCoursesFunction, e, stack);
      return null;
    }
  }

  /// 從全部課程裡挑出屬於 [semester] 的課號（去掉學年學期前綴）。
  static List<String> courseIdsOfSemester(
      List<dynamic> courses, SemesterJson semester) {
    final prefix = "${semester.year}${semester.semester}";
    // 前綴長度不對就不是 <學年3碼><學期1碼>，硬比會把整份清單都配上去。
    if (prefix.length != semesterPrefixLength) return [];

    final ids = <String>[];
    for (final course in courses) {
      if (course is! Map) continue;
      final idnumber = course["idnumber"];
      if (idnumber is! String || !idnumber.startsWith(prefix)) continue;
      final courseId = _courseIdOf(idnumber);
      if (courseId != null && courseId.isNotEmpty) ids.add(courseId);
    }
    return ids;
  }

  /// 沒有 token 就先登入一次。與 [onApiError] 的「不在 connector 內自動重登入」
  /// 政策矛盾；集中成一處是為了讓那個矛盾只有一個位置可以修。
  static Future<void> _ensureToken() async {
    if (wsToken != null) return;
    await login(Model.instance.getAccount(), Model.instance.getPassword());
  }

  static Future<SemesterJson?> getCurrentSemester() async {
    await _ensureToken();
    try {
      final courses = await _getUsersCourses();
      if (courses == null) return null;
      return currentSemesterOf(courses);
    } catch (e, stack) {
      _reportFailure(enrolledCoursesFunction, e, stack);
      return null;
    }
  }

  /// 取進行中課程裡最新的學期（startdate 已到且 enddate 為 0 或未到）；
  /// 學期空檔可能一門進行中的課都沒有，那就退回清單裡最新的那個學期。
  static SemesterJson? currentSemesterOf(List<dynamic> courses,
      {DateTime? now}) {
    // Moodle 的 startdate / enddate 是 Unix 秒。
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    String? inProgress;
    String? latest;

    for (final course in courses) {
      if (course is! Map) continue;
      final idnumber = course["idnumber"];
      if (idnumber is! String || idnumber.length <= semesterPrefixLength) {
        continue;
      }
      final prefix = idnumber.substring(0, semesterPrefixLength);
      if (_isLaterSemester(latest, prefix)) latest = prefix;

      final start = _asUnixSeconds(course["startdate"]);
      final end = _asUnixSeconds(course["enddate"]);
      // enddate 是 0 是 Moodle 表示「沒有結束日」的方式。
      final started = start == null || start <= at;
      final ended = end != null && end != 0 && end <= at;
      if (started && !ended && _isLaterSemester(inProgress, prefix)) {
        inProgress = prefix;
      }
    }

    final picked = inProgress ?? latest;
    if (picked == null) return null;
    return SemesterJson(
      year: picked.substring(0, semesterPrefixLength - 1),
      semester: picked.substring(semesterPrefixLength - 1),
    );
  }

  /// 直接比字串：學年固定 3 碼補零（"099" < "100"），而 '1' < '2' < 'H'
  /// 剛好就是上學期、下學期、暑期的先後。
  static bool _isLaterSemester(String? current, String candidate) =>
      current == null || candidate.compareTo(current) > 0;

  static int? _asUnixSeconds(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse("$value");
  }

  /// 一門課的成績項目，抓不到回 null。`moodlewssettingfileurl` 要留著：
  /// 回饋欄位裡的 `<img>` 要靠它換成可帶 token 取用的網址。
  static Future<MoodleUserGradesEntity?> getScore(String id) async {
    try {
      final uid = await _ensureUserId();
      if (uid == null) return null;

      final result = await _callWs(gradeItemsFunction, {
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "courseid": id,
        "userid": uid,
      });
      final grades = userGradesOf(result);
      if (grades == null) {
        // 不要無聲成功：usergrades 為空回一個空物件會顯示空白的「成功」，
        // 而且那個空物件還會被寫進快取。
        _reportFailure(
          gradeItemsFunction,
          MoodleApiException(
            wsFunction: gradeItemsFunction,
            message: '回應裡沒有 usergrades',
          ),
          StackTrace.current,
        );
        return null;
      }
      return grades;
    } catch (e, stack) {
      _reportFailure(gradeItemsFunction, e, stack);
      return null;
    }
  }

  /// 剝出第一筆 usergrades；形狀不對回 null，不要讓它拋 TypeError 之後
  /// 被 catch 吞成「抓不到」。
  static MoodleUserGradesEntity? userGradesOf(dynamic result) {
    if (result is! Map) return null;
    final entity =
        MoodleGradeItemsEntity.fromJson(Map<String, dynamic>.from(result));
    if (entity.userGrades.isEmpty) return null;
    return entity.userGrades.first;
  }

  /// 這學期每一門課在 Moodle 上的目前總分，抓不到回 null；空清單是合法結果。
  ///
  /// 課名與學期都來自 [_getUsersCourses]（同一次往返已被記憶，多半不必再打）；
  /// 這支 WS 只回 courseid 與格式化過的分數。伺服器端會先把所有課重算一次成績
  /// （regrade_all_courses_if_needed），所以只在使用者真的開那一頁時呼叫。
  static Future<MoodleCourseGradeList?> getCourseGrades() async {
    try {
      final uid = await _ensureUserId();
      if (uid == null) return null;
      final courses = await _getUsersCourses();
      if (courses == null) return null;
      final semester = currentSemesterOf(courses);
      // 一門課的 idnumber 都對不上 <學年3><學期1> 時寧可失敗：學期猜錯會端出
      // 一份看起來很正常、其實是別學期的清單。
      if (semester == null) return null;

      final result = await _callWs(courseGradesFunction, {"userid": uid});
      final grades = courseGradesOf(result);
      if (grades == null) {
        _reportFailure(
          courseGradesFunction,
          MoodleApiException(
            wsFunction: courseGradesFunction,
            message: '回應裡沒有 grades',
          ),
          StackTrace.current,
        );
        return null;
      }
      return MoodleCourseGradeList(
        semester: semester,
        courses: joinCourseGrades(courses, grades, semester),
      );
    } catch (e, stack) {
      _reportFailure(courseGradesFunction, e, stack);
      return null;
    }
  }

  /// 剝出 `grades[]`；形狀不對回 null，空陣列照原樣回空清單
  /// （沒有任何課開放成績是合法狀態，不是抓取失敗）。
  static List<MoodleOverviewGrade>? courseGradesOf(dynamic result) {
    if (result is! Map || result["grades"] is! List) return null;
    return MoodleOverviewGradesEntity.fromJson(
            Map<String, dynamic>.from(result))
        .grades;
  }

  /// 把總分接到課名上。純函式。
  ///
  /// 只留 idnumber 前綴等於這個學期的課；順序照伺服器回的順序，那就是 Moodle
  /// 網頁版總覽表的順序，也省掉中文課名的排序規則。伺服器對「沒開成績、
  /// 不是學生身分、看不到的課」是直接跳過而且不回 warning，所以這裡也不補
  /// 任何佔位列——補了會分不出「老師關掉成績」與「沒這門課」。
  static List<MoodleCourseGradeItem> joinCourseGrades(
    List<dynamic> courses,
    List<MoodleOverviewGrade> grades,
    SemesterJson semester,
  ) {
    final prefix = "${semester.year}${semester.semester}";
    if (prefix.length != semesterPrefixLength) return const [];

    final byMoodleId = <String, Map>{};
    for (final course in courses) {
      if (course is! Map) continue;
      final id = _courseKeyOf(course);
      if (id != null) byMoodleId[id] = course;
    }

    final rows = <MoodleCourseGradeItem>[];
    for (final grade in grades) {
      final course = byMoodleId[grade.courseid.toString()];
      if (course == null) continue;
      final idnumber = course["idnumber"];
      if (idnumber is! String || !idnumber.startsWith(prefix)) continue;
      final courseId = _courseIdOf(idnumber);
      if (courseId == null || courseId.isEmpty) continue;
      // 課程總分是文字/無評分型態時伺服器回空字串，畫成空白會像壞掉；
      // 藏起來的那個 "-" 則原樣帶下去，永遠不解析成數字。
      final formatted = HtmlUtils.clean(grade.grade).trim();
      rows.add(MoodleCourseGradeItem(
        courseId: courseId,
        name: _courseDisplayName(course, courseId),
        grade: formatted.isEmpty ? "-" : formatted,
      ));
    }
    return rows;
  }

  /// fullname 優先、shortname 退路、都空就用課號。與待辦 tile 的
  /// `UpcomingEventUtils.courseLabelOf`（shortname 優先）相反是刻意的：
  /// 那裡課名只是與活動名共用一行的副標，這裡它是主角，課號另有一行。
  static String _courseDisplayName(Map course, String courseId) {
    for (final key in const ["fullname", "shortname"]) {
      final raw = course[key];
      if (raw is! String) continue;
      // format_string 過的（`&` 會是 `&amp;`），先還原實體再剝前綴。
      final name =
          MoodleCourseNameUtils.stripCoursePrefix(HtmlUtils.clean(raw));
      if (name.isNotEmpty) return name;
    }
    return courseId;
  }

  /// [now] 當天 00:00 往前推 [actionEventsLookbackDays] 天的 Unix 秒。
  static int actionEventsTimesortFrom(DateTime now) =>
      DateTime(now.year, now.month, now.day - actionEventsLookbackDays)
          .millisecondsSinceEpoch ~/
      1000;

  /// 所有課程的待辦事件。失敗回 null；空清單是合法結果，不要映成 null。
  /// 回滿一頁就帶 `aftereventid` 再翻；第一頁失敗才算失敗，後面失敗就用手上的。
  static Future<List<MoodleActionEvent>?> getActionEvents({
    int? timesortFrom,
    int limitnum = actionEventsLimit,
  }) async {
    final from =
        (timesortFrom ?? actionEventsTimesortFrom(DateTime.now())).toString();
    final all = <MoodleActionEvent>[];
    int? after;
    for (var page = 0; page < actionEventsMaxPages; page++) {
      final MoodleCoreCalendarActionEvents? parsed;
      try {
        final result = await _callWs(actionEventsFunction, {
          "moodlewssettingfilter": "true",
          "moodlewssettingfileurl": "true",
          "timesortfrom": from,
          "limitnum": limitnum.toString(),
          // 只要還在修的課。
          "limittononsuspendedevents": "1",
          if (after != null) "aftereventid": after.toString(),
        });
        parsed = actionEventsPageOf(result);
        if (parsed == null) {
          throw MoodleApiException(
            wsFunction: actionEventsFunction,
            message: '回應裡沒有 events',
          );
        }
      } catch (e, stack) {
        _reportFailure(actionEventsFunction, e, stack);
        return page == 0 ? null : all;
      }
      all.addAll(parsed.events);
      after = nextActionEventsPage(parsed, limitnum);
      if (after == null) break;
    }
    return all;
  }

  /// 下一頁的 `aftereventid`；沒有下一頁回 null。「回滿一頁」是唯一的訊號：
  /// 伺服器不回總數，也不回 has-more。
  static int? nextActionEventsPage(
      MoodleCoreCalendarActionEvents page, int limitnum) {
    if (page.events.length < limitnum) return null;
    return page.lastid;
  }

  /// 同 [actionEventsPageOf]，只回 events。
  static List<MoodleActionEvent>? actionEventsOf(dynamic result) =>
      actionEventsPageOf(result)?.events;

  /// 一頁回應剝成模型（含翻頁用的 lastid）；形狀不對回 null。名稱欄位都是
  /// format_string 過的（`&` 會是 `&amp;`），在這裡過 [HtmlUtils.clean]。
  static MoodleCoreCalendarActionEvents? actionEventsPageOf(dynamic result) {
    if (result is! Map || result["events"] is! List) return null;
    final parsed = MoodleCoreCalendarActionEvents.fromJson(
        Map<String, dynamic>.from(result));
    for (final event in parsed.events) {
      event.name = HtmlUtils.clean(event.name);
      final activityname = event.activityname;
      if (activityname != null) {
        event.activityname = HtmlUtils.clean(activityname);
      }
      final course = event.course;
      if (course != null) {
        course.fullname = HtmlUtils.clean(course.fullname);
        course.shortname = HtmlUtils.clean(course.shortname);
      }
    }
    return parsed;
  }

  /// 這門課（Moodle 內部 id）的全部作業，抓不到回 null。回的日期已套過 override；
  /// `moodlewssettingfileurl` 要留著，intro 的 `@@PLUGINFILE@@` 才會換成網址。
  static Future<List<MoodleAssignment>?> getAssignments(String courseId) async {
    try {
      final result = await _callWs(assignmentsFunction, {
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "courseids[0]": courseId,
      });
      final assignments = assignmentsOf(result);
      if (assignments == null) {
        // courses 為空是站台用 warnings 說「未選課或無權限」，不是「沒有作業」。
        _reportFailure(
          assignmentsFunction,
          MoodleApiException(
            wsFunction: assignmentsFunction,
            message: 'courses 為空：${_firstWarningMessage(result)}',
          ),
          StackTrace.current,
        );
        return null;
      }
      return assignments;
    } catch (e, stack) {
      _reportFailure(assignmentsFunction, e, stack);
      return null;
    }
  }

  /// `courses` 為空回 null（warnings：未選課或無權限）；有課但沒作業回空清單。
  /// `name` 是 format_string 過的，在這裡 [HtmlUtils.clean]，快取存的才是還原後的。
  static List<MoodleAssignment>? assignmentsOf(dynamic result) {
    if (result is! Map) return null;
    final entity = MoodleModAssignGetAssignments.fromJson(
        Map<String, dynamic>.from(result));
    if (entity.courses.isEmpty) return null;
    final list = [for (final c in entity.courses) ...c.assignments];
    for (final a in list) {
      a.name = HtmlUtils.clean(a.name);
    }
    return list;
  }

  /// 一份作業對自己的繳交狀態、成績與回饋，抓不到回 null。
  /// `lastattempt.submission` 缺席代表還沒繳交，是正常回應。
  static Future<MoodleAssignSubmissionStatus?> getSubmissionStatus(
      int assignId) async {
    try {
      final uid = await _ensureUserId();
      if (uid == null) return null;

      final result = await _callWs(submissionStatusFunction, {
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "assignid": assignId.toString(),
        "userid": uid,
      });
      return submissionStatusOf(result);
    } catch (e, stack) {
      _reportFailure(submissionStatusFunction, e, stack);
      return null;
    }
  }

  /// 要把現有線上文字原樣送回去之前打的那一趟：拿**資料庫原文**與內嵌檔案。
  ///
  /// **這一份回應不可以包成 [MoodleAssignSubmissionStatus]、也不可以進快取。**
  /// 三個設定缺一不可，而且 `fileurl` 要單獨看：`core_external\util::format_text`
  /// 先做 `file_rewrite_pluginfile_urls` 才檢查 `raw`，只送 raw 的話
  /// `@@PLUGINFILE@@` 照樣會被換成絕對網址。
  static Future<AssignOnlineTextEdit?> getOnlineTextForEdit(
    int assignId, {
    required bool teamSubmission,
  }) async {
    try {
      final uid = await _ensureUserId();
      if (uid == null) return null;

      final result = await _callWs(submissionStatusFunction, {
        "moodlewssettingraw": "true",
        "moodlewssettingfilter": "false",
        "moodlewssettingfileurl": "false",
        "assignid": assignId.toString(),
        "userid": uid,
      });
      return onlineTextForEditOf(result, teamSubmission: teamSubmission);
    } catch (e, stack) {
      _reportFailure(submissionStatusFunction, e, stack);
      return null;
    }
  }

  /// 形狀不對、或這份作業還沒有繳交紀錄時回 null。[teamSubmission] 決定要讀
  /// `teamsubmission` 還是 `submission`——順序不能用 null 合併，見
  /// `MoodleAssignSubmissionStatus.submissionFor`。
  @visibleForTesting
  static AssignOnlineTextEdit? onlineTextForEditOf(
    dynamic result, {
    required bool teamSubmission,
  }) {
    if (result is! Map) return null;
    final status = MoodleAssignSubmissionStatus.fromJson(
        Map<String, dynamic>.from(result));
    final last = status.lastattempt;
    final sub = teamSubmission
        ? (last?.teamsubmission ?? last?.submission)
        : last?.submission;
    if (sub == null) return null;
    return (rawText: sub.onlineText, inlineFiles: sub.onlineTextFiles);
  }

  /// 形狀不對回 null。`gradefordisplay` 是 HTML 片段（如 `85.00&nbsp;/&nbsp;100.00`），
  /// 在這裡 [HtmlUtils.clean] 成純文字，下游只進 Text。`previousattempts` 底下
  /// 那幾筆是同一個 PARAM_RAW 欄位，同樣要清。
  static MoodleAssignSubmissionStatus? submissionStatusOf(dynamic result) {
    if (result is! Map) return null;
    final status = MoodleAssignSubmissionStatus.fromJson(
        Map<String, dynamic>.from(result));
    final feedback = status.feedback;
    if (feedback != null) {
      feedback.gradefordisplay = HtmlUtils.clean(feedback.gradefordisplay);
    }
    for (final attempt in status.previousattempts) {
      final grade = attempt.grade;
      if (grade != null) {
        grade.gradefordisplay = HtmlUtils.clean(grade.gradefordisplay);
      }
    }
    return status;
  }

  /// 作業的網頁位址。[cmid] 是 course module id，不是 assign id。
  static String assignViewUrl(int cmid) => "$host/mod/assign/view.php?id=$cmid";

  /// 存一次繳交。[draftItemId] 為 null＝不動檔案。
  ///
  /// [onlineText] 為 null 是「這份作業沒開 onlinetext 外掛」，**不是**「不動
  /// 線上文字」——那個對稱不存在，見 `AssignSubmissionDraft.onlineText`。
  ///
  /// `files_filemanager` 一旦送出，伺服器會把繳交區**同步**成那個 draft 區的
  /// 內容（`file_save_draft_area_files` 會把不在 draft 區裡的舊檔案 delete
  /// 掉），所以絕對不要為了「只是加一個檔案」而送一個只有新檔案的 draft。
  ///
  /// 扁平鍵是刻意的：`DioConnector.dioOptions` 的 contentType 是
  /// form-urlencoded，`preferences[0][type]`（toggleSetting）已經是同一種寫法。
  static Future<bool> saveSubmission({
    required int assignId,
    String? onlineText,
    int? draftItemId,
  }) async {
    if (onlineText == null && draftItemId == null) {
      throw ArgumentError('plugindata 是必填結構，至少要有一個外掛的資料');
    }
    final data = <String, dynamic>{"assignmentid": assignId.toString()};
    if (onlineText != null) {
      data["plugindata[onlinetext_editor][text]"] = onlineText;
      data["plugindata[onlinetext_editor][format]"] =
          onlineTextFormatHtml.toString();
      // itemid 送 0：file_postupdate_standard_editor 的 empty($editor['itemid'])
      // 分支會整段跳過 draft 同步，內文沒有內嵌檔案就走這條（官方 App 相同）。
      data["plugindata[onlinetext_editor][itemid]"] = "0";
    }
    if (draftItemId != null) {
      data["plugindata[files_filemanager]"] = draftItemId.toString();
    }
    try {
      final result = await _callWs(saveSubmissionFunction, data);
      final shape =
          writeShapeErrorOf(result, wsFunction: saveSubmissionFunction);
      if (shape != null) throw shape;
      final warning =
          writeWarningOf(result, wsFunction: saveSubmissionFunction);
      if (warning != null) throw warning;
      return true;
    } catch (e, stack) {
      _reportAndRethrow(saveSubmissionFunction, e, stack);
    }
  }

  /// 送出評分。[acceptStatement] 只在使用者真的勾了同意時才傳 true——
  /// 伺服器會據此觸發 statement_accepted 稽核事件，代勾等於偽造同意紀錄。
  static Future<bool> submitForGrading({
    required int assignId,
    required bool acceptStatement,
  }) async {
    try {
      final result = await _callWs(submitForGradingFunction, {
        "assignmentid": assignId.toString(),
        "acceptsubmissionstatement": acceptStatement ? "1" : "0",
      });
      final shape =
          writeShapeErrorOf(result, wsFunction: submitForGradingFunction);
      if (shape != null) throw shape;
      final warning =
          writeWarningOf(result, wsFunction: submitForGradingFunction);
      if (warning != null) throw warning;
      return true;
    } catch (e, stack) {
      _reportAndRethrow(submitForGradingFunction, e, stack);
    }
  }

  /// 站台有沒有對這個 token 開放「移除繳交」。site_info 還沒載入時 fail-open，
  /// 態度與 [wsFunctionBlocked] 一致。
  static bool get canRemoveSubmission =>
      wsFunctionBlocked(removeSubmissionFunction) == null;

  /// 同上，問的是「開始計時作答」。
  static bool get canStartSubmission =>
      wsFunctionBlocked(startSubmissionFunction) == null;

  /// 同上，問的是「沿用上一次繳交」。**多數站台會是 false**：這一支不在
  /// MOODLE_OFFICIAL_MOBILE_SERVICE 內，見 [copyPreviousAttemptFunction]。
  static bool get canCopyPreviousAttempt =>
      wsFunctionBlocked(copyPreviousAttemptFunction) == null;

  /// 移除一次繳交。成功回 true，其餘一律拋 [MoodleApiException]。
  ///
  /// `userid` 一定要送真的 id：這一支沒有 VALUE_DEFAULT，而 0 **不代表**
  /// 「我自己」——`can_edit_submission($userid, $USER->id)` 的自己那一支是
  /// `$userid == $graderid`，帶 0 會落到 `mod/assign:editothersubmission`，
  /// 學生沒有那個權限，回來的是 couldnotremovesubmission。
  ///
  /// `status` 要**獨立於 warnings** 判：`assign::remove_submission()` 在
  /// `!$submission`（跟另一台裝置搶）時回 false 而且一句錯誤都不留，
  /// `{status: false, warnings: []}` 是真的到得了的回應，把它當成功就是把
  /// 什麼都沒做報成刪除成功。
  static Future<bool> removeSubmission({required int assignId}) async {
    try {
      final uid = await _ensureUserId();
      if (uid == null) {
        throw MoodleApiException(
          wsFunction: removeSubmissionFunction,
          message: '拿不到 userid，這一支不能用 0 代表自己',
        );
      }
      final result = await _callWs(
        removeSubmissionFunction,
        {"assignid": assignId.toString(), "userid": uid},
        treatWarningsAsError: true,
      );
      final shape =
          writeObjectShapeErrorOf(result, wsFunction: removeSubmissionFunction);
      if (shape != null) throw shape;
      if ((result as Map)["status"] != true) {
        throw MoodleApiException(
          wsFunction: removeSubmissionFunction,
          errorcode: "couldnotremovesubmission",
          message: 'status 是 false 但沒有任何 warning',
          siteFunctionVersion: siteInfo?.wsVersion(removeSubmissionFunction),
        );
      }
      return true;
    } catch (e, stack) {
      _reportAndRethrow(removeSubmissionFunction, e, stack);
    }
  }

  /// 開始一次有時限的作答。
  ///
  /// 刻意**不**傳 `treatWarningsAsError`：這一支的三個 warning 裡只有
  /// `submissionnotopen` 是真的失敗。`timelimitnotenabled` 是「站台把計時
  /// 功能整個關了」——那等於沒有計時器，照常進編輯頁；`opensubmissionexists`
  /// 是「已經在跑了」，那是接續不是錯誤。認不得的 code 才拋。
  static Future<MoodleAssignStartResult> startSubmission(
      {required int assignId}) async {
    try {
      final result = await _callWs(
          startSubmissionFunction, {"assignid": assignId.toString()});
      final shape =
          writeObjectShapeErrorOf(result, wsFunction: startSubmissionFunction);
      if (shape != null) throw shape;
      final map = result as Map;
      final outcome = _startOutcomeOf(map["warnings"]);
      return MoodleAssignStartResult(
        outcome: outcome,
        submissionId: int.tryParse('${map["submissionid"] ?? 0}') ?? 0,
      );
    } catch (e, stack) {
      _reportAndRethrow(startSubmissionFunction, e, stack);
    }
  }

  /// warnings[] → 結果。有任何 warning 時伺服器什麼都沒寫、`submissionid`
  /// 是 0；warnings 是可以累加的（同時關閉又沒時限會回兩則），所以
  /// 「真的失敗」的那一個優先。
  static AssignStartOutcome _startOutcomeOf(dynamic warnings) {
    if (warnings is! List || warnings.isEmpty) {
      return AssignStartOutcome.started;
    }
    final codes = <String>{
      for (final w in warnings)
        if (w is Map && w["warningcode"] != null) w["warningcode"].toString(),
    };
    if (codes.contains('submissionnotopen')) return AssignStartOutcome.notOpen;
    if (codes.contains('timelimitnotenabled')) {
      return AssignStartOutcome.noTimeLimit;
    }
    if (codes.contains('opensubmissionexists')) {
      return AssignStartOutcome.alreadyRunning;
    }
    throw MoodleApiException(
      wsFunction: startSubmissionFunction,
      errorcode: codes.isEmpty ? null : codes.first,
      message: '認不得的 warningcode',
      siteFunctionVersion: siteInfo?.wsVersion(startSubmissionFunction),
    );
  }

  /// 把上一次的繳交複製進這一次。回的是**裸的 warnings 陣列**，跟
  /// `save_submission` 同一個陷阱，所以判讀點也一樣是
  /// [writeShapeErrorOf] + [writeWarningOf]，不能用 `treatWarningsAsError`。
  ///
  /// 唯一的 warningcode 是 `couldnotcopyprevioussubmission`，而它**不在**
  /// `generate_warning` 的訊息表裡，回來的 `message` 會是
  /// 「Unknown warning type.」，真正的原因只在伺服器語言的 `item` 裡。
  /// 所以那個 code 只能對映到一句涵蓋性的話，其餘由重抓的狀態卡自己說。
  static Future<bool> copyPreviousAttempt({required int assignId}) async {
    try {
      final result = await _callWs(
          copyPreviousAttemptFunction, {"assignmentid": assignId.toString()});
      final shape =
          writeShapeErrorOf(result, wsFunction: copyPreviousAttemptFunction);
      if (shape != null) throw shape;
      final warning =
          writeWarningOf(result, wsFunction: copyPreviousAttemptFunction);
      if (warning != null) throw warning;
      return true;
    } catch (e, stack) {
      _reportAndRethrow(copyPreviousAttemptFunction, e, stack);
    }
  }

  /// 把 Moodle 上的一個檔案抓到 [savePath]（重傳舊繳交檔案用）。網址一律先過
  /// [fileUrlWithToken]；非自家 host 直接回 false，不附憑證也不下載。
  static Future<bool> downloadFileTo(
    String fileUrl,
    String savePath, {
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    if (!isOwnHost(Uri.tryParse(fileUrl))) {
      Log.e("refuse to download a foreign host file");
      return false;
    }
    try {
      await fileDownloader(fileUrlWithToken(fileUrl), savePath,
          cancelToken: cancelToken, onProgress: onProgress);
      return true;
    } catch (e, stack) {
      Log.eWithStack("download submission file: $e", stack);
      return false;
    }
  }

  /// 這門課（Moodle 內部 id）的全部測驗，抓不到回 null。日期已套過 override；
  /// `moodlewssettingfileurl` 要留著，intro 的 `@@PLUGINFILE@@` 才會換成網址。
  static Future<List<MoodleQuiz>?> getQuizzes(String courseId) async {
    try {
      final result = await _callWs(quizzesFunction, {
        "moodlewssettingfilter": "true",
        "moodlewssettingfileurl": "true",
        "courseids[0]": courseId,
      });
      final quizzes = quizzesOf(result);
      if (quizzes == null) {
        _reportFailure(
          quizzesFunction,
          MoodleApiException(
            wsFunction: quizzesFunction,
            message: 'quizzes 為空：${_firstWarningMessage(result)}',
          ),
          StackTrace.current,
        );
        return null;
      }
      return quizzes;
    } catch (e, stack) {
      _reportFailure(quizzesFunction, e, stack);
      return null;
    }
  }

  /// `quizzes` 缺席或形狀不對回 null；**空清單加上 warnings 也回 null**——
  /// `util::validate_courses` 把沒權限的課從 courses 移除並塞一筆 warning，
  /// 那是「沒選這門課」而不是「這門課沒有測驗」。`name` 是 format_string
  /// 過的，在這裡 [HtmlUtils.clean]，快取存的才是還原後的。
  static List<MoodleQuiz>? quizzesOf(dynamic result) {
    if (result is! Map || result["quizzes"] is! List) return null;
    final entity = MoodleModQuizGetQuizzesByCourses.fromJson(
        Map<String, dynamic>.from(result));
    final warnings = result["warnings"];
    if (entity.quizzes.isEmpty && warnings is List && warnings.isNotEmpty) {
      return null;
    }
    for (final q in entity.quizzes) {
      q.name = HtmlUtils.clean(q.name);
    }
    return entity.quizzes;
  }

  /// 作答紀錄要打哪一支。判準與官方 App 相同（site_info 的 `functions[]`）：
  /// 有 `mod_quiz_get_user_quiz_attempts` 就用它，否則退回 5.0 起 deprecated
  /// 的舊名。site_info 還沒載入時 fail-open 到舊名——那是 4.5（NTUST 現況）
  /// 唯一存在的一支。
  @visibleForTesting
  static String preferredQuizAttemptsFunction() {
    final profile = siteInfo;
    if (profile == null || !profile.knowsWsFunctions) {
      return quizAttemptsFunction;
    }
    if (profile.wsAvailable(quizUserAttemptsFunction)) {
      return quizUserAttemptsFunction;
    }
    return quizAttemptsFunction;
  }

  /// 自己在這個測驗的作答紀錄，抓不到回 null。空清單是合法結果。
  ///
  /// 不送 `userid`：兩支的 PHP 都有 `if (empty($params['userid']))
  /// $userid = $USER->id;`，與通知那三支不同（那三支送 0 會直接 accessdenied）。
  static Future<List<MoodleQuizAttempt>?> getQuizAttempts(int quizId) async {
    final wsFunction = preferredQuizAttemptsFunction();
    try {
      final result = await _callWs(wsFunction, {
        "quizid": quizId.toString(),
        "status": quizAttemptsStatus,
        "includepreviews": "0",
      });
      final attempts = quizAttemptsOf(result);
      if (attempts == null) {
        _reportFailure(
          wsFunction,
          MoodleApiException(
            wsFunction: wsFunction,
            message: '回應裡沒有 attempts',
          ),
          StackTrace.current,
        );
        return null;
      }
      return attempts;
    } catch (e, stack) {
      _reportFailure(wsFunction, e, stack);
      return null;
    }
  }

  /// 形狀不對回 null。preview 由伺服器濾掉（`includepreviews=0`），這裡再濾
  /// 一次是防呆：老師帳號的預覽不該算進作答次數。
  static List<MoodleQuizAttempt>? quizAttemptsOf(dynamic result) {
    if (result is! Map || result["attempts"] is! List) return null;
    final parsed = MoodleModQuizGetUserAttempts.fromJson(
        Map<String, dynamic>.from(result));
    return [
      for (final a in parsed.attempts)
        if (!a.isPreview) a
    ];
  }

  /// 這個測驗的最佳成績與及格分數，抓不到回 null。`hasgrade == false` 是
  /// 正常回應（還沒作答、或老師關掉分數顯示），不是失敗。
  static Future<MoodleQuizBestGrade?> getQuizBestGrade(int quizId) async {
    try {
      final result = await _callWs(quizBestGradeFunction, {
        "quizid": quizId.toString(),
      });
      final grade = quizBestGradeOf(result);
      if (grade == null) {
        _reportFailure(
          quizBestGradeFunction,
          MoodleApiException(
            wsFunction: quizBestGradeFunction,
            message: '回應裡沒有 hasgrade',
          ),
          StackTrace.current,
        );
        return null;
      }
      return grade;
    } catch (e, stack) {
      _reportFailure(quizBestGradeFunction, e, stack);
      return null;
    }
  }

  /// 形狀不對回 null。`hasgrade` 是唯一必填欄位，用它當形狀的標記。
  static MoodleQuizBestGrade? quizBestGradeOf(dynamic result) {
    if (result is! Map || result["hasgrade"] == null) return null;
    return MoodleQuizBestGrade.fromJson(Map<String, dynamic>.from(result));
  }

  /// 測驗的網頁位址。[cmid] 是 course module id，不是 quiz id。
  static String quizViewUrl(int cmid) => "$host/mod/quiz/view.php?id=$cmid";

  /// 站內通知（popup）清單，抓不到回 null。回應本身就帶 `unreadcount`，
  /// 開頁時不必再打一趟未讀數。
  ///
  /// 不送 `moodlewssettingfilter` / `moodlewssettingfileurl`：這支 WS 是直接
  /// 讀資料表，沒有呼叫 external 的 format_text，送了無效。
  ///
  /// `newestfirst` 拿回來的是「最新的 N 則」，**不分已讀未讀**，而外層的
  /// `unreadcount` 算的是收件匣全部的未讀。視窗外還有未讀時要用 `offset`
  /// 往下翻，否則會出現「紅點寫 5、清單裡一顆未讀圓點都沒有」，而使用者
  /// 除了那顆有破壞性的「全部標為已讀」之外找不到它們。
  static Future<MoodleNotificationList?> getNotifications({
    int limit = notificationsLimit,
  }) async {
    final String? uid;
    try {
      uid = await _ensureUserId();
    } catch (e, stack) {
      _reportFailure(popupNotificationsFunction, e, stack);
      return null;
    }
    if (uid == null) return null;

    final all = <MoodleNotification>[];
    var unreadcount = 0;
    for (var page = 0; page < notificationsMaxPages; page++) {
      final MoodleNotificationList? parsed;
      try {
        final result = await _callWs(popupNotificationsFunction, {
          "useridto": uid,
          "newestfirst": "1",
          "limit": limit.toString(),
          "offset": (page * limit).toString(),
        });
        parsed = notificationsOf(result);
        if (parsed == null) {
          throw MoodleApiException(
            wsFunction: popupNotificationsFunction,
            message: '回應裡沒有 notifications',
          );
        }
      } catch (e, stack) {
        _reportFailure(popupNotificationsFunction, e, stack);
        // 第一頁就失敗才算整趟失敗；已經拿到的頁數照樣給畫面。
        if (page == 0) return null;
        break;
      }
      all.addAll(parsed.notifications);
      unreadcount = parsed.unreadcount;
      // 回不滿一頁就是到底了；未讀已經全部在手上也不必再翻。
      if (parsed.notifications.length < limit) break;
      if (all.where((n) => !n.read).length >= unreadcount) break;
    }
    return MoodleNotificationList(notifications: all, unreadcount: unreadcount);
  }

  /// 形狀不對回 null。`subject` 與 `contexturlname` 服務端只做過 PARAM_TEXT
  /// （標籤剝掉、實體留著），在這裡 [HtmlUtils.clean]，快取存的才是還原後的。
  @visibleForTesting
  static MoodleNotificationList? notificationsOf(dynamic result) {
    if (result is! Map || result["notifications"] is! List) return null;
    final list =
        MoodleNotificationList.fromJson(Map<String, dynamic>.from(result));
    for (final n in list.notifications) {
      n.subject = HtmlUtils.clean(n.subject);
      final name = n.contexturlname;
      if (name != null) n.contexturlname = HtmlUtils.clean(name);
    }
    return list;
  }

  /// 未讀數要打哪一支。**刻意與官方 App 相反**：TAT 的清單只顯示 popup 通知，
  /// 用 core_ 的總數會出現「紅點 3、點進去只有 1 則未讀」；官方 App 的清單是
  /// `core_message_get_messages`（全部 notifications），所以它反過來。
  /// site_info 還沒載入時 fail-open，態度與 [wsFunctionBlocked] 一致。
  @visibleForTesting
  static String? preferredUnreadCountFunction() {
    final profile = siteInfo;
    if (profile == null || !profile.knowsWsFunctions) {
      return popupUnreadCountFunction;
    }
    if (profile.wsAvailable(popupUnreadCountFunction)) {
      return popupUnreadCountFunction;
    }
    if (profile.wsAvailable(unreadNotificationCountFunction)) {
      return unreadNotificationCountFunction;
    }
    // 兩支都沒有：紅點交給清單回應裡自帶的 unreadcount。
    return null;
  }

  /// 未讀數，抓不到回 null。
  ///
  /// `useridto` 一定要送真的 id：這兩支都沒有「0 代入目前使用者」那一步
  /// （文件寫的 `0 for any user` 會把人騙進去），送 0 會被判 accessdenied。
  static Future<int?> getUnreadNotificationCount() async {
    final wsFunction = preferredUnreadCountFunction();
    if (wsFunction == null) return null;
    try {
      final uid = await _ensureUserId();
      if (uid == null) return null;
      return unreadCountOf(await _callWs(wsFunction, {"useridto": uid}));
    } catch (e, stack) {
      _reportFailure(wsFunction, e, stack);
      return null;
    }
  }

  /// 這兩支回的是裸 JSON 數字，不是物件。
  @visibleForTesting
  static int? unreadCountOf(dynamic result) => switch (result) {
        final int n => n,
        final num n => n.toInt(),
        final String s => int.tryParse(s),
        _ => null,
      };

  /// 標記單則已讀。`timeread` 省略（VALUE_DEFAULT 0）→ 伺服器用 `time()`。
  ///
  /// `treatWarningsAsError` 照寫（寫入路徑的慣例），但這支的 warnings 在伺服器
  /// 端是初始化後從不 append 的空陣列，實際上不會觸發。通知被伺服器的清理排程
  /// 刪掉時回的是 `dml_missing_record_exception`——已讀 7 天後就會發生，
  /// 呼叫端不可以讓它變成整頁的錯誤畫面。
  static Future<bool> markNotificationRead(int notificationId) async {
    try {
      await _callWs(
        markNotificationReadFunction,
        {"notificationid": notificationId.toString()},
        treatWarningsAsError: true,
      );
      return true;
    } catch (e, stack) {
      _reportFailure(markNotificationReadFunction, e, stack);
      return false;
    }
  }

  /// 全部標為已讀。回的是裸 bool，沒有 warnings 外殼，`treatWarningsAsError`
  /// 對它無效，所以「沒有拋例外」不等於成功，要看值。
  ///
  /// `useridto` 一樣不能送 0：`useridto` 與 `useridfrom` 都是 0 時伺服器判
  /// accessdenied。它標記的是 `{notifications}` 全部，不只 popup。
  static Future<bool> markAllNotificationsRead() async {
    try {
      final uid = await _ensureUserId();
      if (uid == null) return false;
      final result =
          await _callWs(markAllNotificationsReadFunction, {"useridto": uid});
      return result == true;
    } catch (e, stack) {
      _reportFailure(markAllNotificationsReadFunction, e, stack);
      return false;
    }
  }

  static String _firstWarningMessage(dynamic result) {
    if (result is! Map) return "";
    final warnings = result["warnings"];
    if (warnings is! List || warnings.isEmpty) return "";
    final first = warnings.first;
    return first is Map ? (first["message"]?.toString() ?? "") : "";
  }

  static Future<MoodleProfileEntity?> getProfile() async {
    try {
      // fromJson 之前一定要先判錯（_callWs 已做）：每個欄位都有
      // defaultValue，錯誤包丟進去會得到一個看起來完全合法的空 profile。
      final result = await _callWs(siteInfoFunction, const {});
      final profile =
          MoodleProfileEntity.fromJson(result as Map<String, dynamic>);
      siteInfo = profile;
      return profile;
    } catch (e, stack) {
      _reportFailure(siteInfoFunction, e, stack);
      return null;
    }
  }

  static Future<MoodleSettingEntity?> getSettings() async {
    const wsFunction = "core_message_get_user_notification_preferences";
    await _ensureToken();
    try {
      final result = await _callWs(wsFunction, const {});
      return MoodleSettingEntity.fromJson(result as Map<String, dynamic>);
    } catch (e, stack) {
      _reportFailure(wsFunction, e, stack);
      return null;
    }
  }

  /// 切換 Moodle 通知設定，成功回 true。唯一送 `treatWarningsAsError: true`
  /// 的呼叫：寫入只要有一筆 warning 就代表偏好設定沒有真的存進去。
  static Future<bool> toggleSetting(String key, List<String> values) async {
    const wsFunction = "core_user_update_user_preferences";
    await _ensureToken();
    try {
      await _callWs(
        wsFunction,
        {
          "preferences[0][type]": "${key}_enabled",
          "preferences[0][value]": values.join(","),
          "moodlewssettingfilter": true,
          "moodlewssettingfileurl": true,
        },
        treatWarningsAsError: true,
      );
      return true;
    } catch (e, stack) {
      _reportFailure(wsFunction, e, stack);
      return false;
    }
  }

  /// upload.php 的 body 先 decode 成 dynamic：String 就 jsonDecode，
  /// 已經是 Map/List 就原樣（測試注入時方便）。解不開回 null。
  static dynamic decodeUploadBody(dynamic body) {
    if (body is String) {
      try {
        return jsonDecode(body);
      } catch (_) {
        return null;
      }
    }
    return body;
  }

  /// webservice/upload.php 的回應 → draft 檔案紀錄。
  ///
  /// 三種形狀都要判：
  /// 1. `{error, errorcode, ...}`（AJAX_SCRIPT 的例外包，key 是 `error` 不是
  ///    `message`，所以 [moodleErrorOf] 認不出來）。
  /// 2. 陣列裡的錯誤元素（`errortype` fileoversized / filenameexist，HTTP 照樣 200）。
  /// 3. 正常的 filerecord 陣列。
  ///
  /// 傳進來的通常是 String：upload.php 因為 `$_FILES` 非空，Content-Type 送的是
  /// text/plain，Dio 不會替我們 jsonDecode，所以這裡先過 [decodeUploadBody]。
  static MoodleDraftFile draftFileOf(dynamic body) {
    final data = decodeUploadBody(body);

    if (data is Map && data.containsKey("error")) {
      throw MoodleApiException(
        wsFunction: uploadEndpoint,
        errorcode: data["errorcode"]?.toString(),
        message: data["error"]?.toString(),
        debugInfo: data["debuginfo"]?.toString(),
      );
    }

    if (data is! List || data.isEmpty) {
      throw MoodleApiException(
        wsFunction: uploadEndpoint,
        errorcode: "nofile",
        message: "upload.php 沒有回傳任何檔案紀錄",
      );
    }

    final first = data.first;
    if (first is! Map) {
      throw MoodleApiException(
        wsFunction: uploadEndpoint,
        errorcode: "nofile",
        message: "upload.php 的回應形狀不對",
      );
    }
    final file = MoodleDraftFile.fromJson(Map<String, dynamic>.from(first));
    if (file.isError) {
      throw MoodleApiException(
        wsFunction: uploadEndpoint,
        errorcode: file.errortype,
        message: file.error,
      );
    }
    return file;
  }

  /// core_user_update_picture 的回應 → 結果。形狀不對回 null。
  static MoodleUpdatePictureResult? updatePictureResultOf(dynamic result) {
    if (result is! Map || !result.containsKey("success")) return null;
    return MoodleUpdatePictureResult.fromJson(
        Map<String, dynamic>.from(result));
  }

  /// 寫入路徑的收尾：照樣送 [onApiError]（token 死掉要清），但不吞掉——
  /// 呼叫端要拿 errorcode 換一句使用者看得懂的話。讀取路徑吞例外是因為它們
  /// 有快取可以退，這條沒有。
  static Never _reportAndRethrow(
      String wsFunction, Object e, StackTrace stack) {
    _reportFailure(wsFunction, e, stack);
    Error.throwWithStackTrace(e, stack);
  }

  /// 把一個檔案送進自己的 draft 檔案區，回 draft itemid。
  ///
  /// [draftItemId] 為 null（或 0）時不送 itemid：
  /// `optional_param('itemid', 0, PARAM_INT)` 為 0 時伺服器會叫
  /// `file_get_unused_draft_itemid()` 開一個新的。要把多個檔案放進同一個
  /// draft 區時，第二個以後要把第一次拿到的 itemid 送回來——同一區裡檔名重複
  /// 會拿到 filenameexist，所以呼叫端必須先擋重名。
  /// token 放 POST 欄位不放 query：`get_request_parameter` 先看 `$_POST`，
  /// 而 query string 會被寫進學校的 access log。filepath 也不送，預設就是 '/'。
  ///
  /// MultipartFile 刻意不指定 contentType：upload.php 從不讀那一欄，
  /// `process_new_icon` 是用 `getimagesize()` 嗅內容的。
  static Future<int?> uploadDraftFile(
    File file, {
    required String filename,
    int? draftItemId,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final token = wsToken;
    if (token == null) return null;
    try {
      final formData = FormData.fromMap({
        "token": token,
        if (draftItemId != null && draftItemId > 0)
          "itemid": draftItemId.toString(),
        uploadFieldName:
            await MultipartFile.fromFile(file.path, filename: filename),
      });
      final body = await uploadPost(
        ConnectorParameter(uploadEndpoint),
        formData: formData,
        sendTimeout: uploadSendTimeout,
        onSendProgress: onProgress,
        cancelToken: cancelToken,
      );
      return draftFileOf(body).itemid;
    } catch (e, stack) {
      _reportAndRethrow(uploadEndpoint, e, stack);
    }
  }

  /// 套用（或移除）頭貼。回伺服器算出來的結果；形狀不對回 null。
  ///
  /// `draftitemid` 沒有 VALUE_DEFAULT，移除時也要送，送 0。
  /// `userid` 不送：這一支真的把 0 當成自己（`empty($params['userid']) or
  /// $params['userid'] == $USER->id`），與那三支通知 function 不同。
  /// `treatWarningsAsError` 對它無效：伺服器端 warnings 寫死是空陣列，
  /// 唯一的訊號是 success；照樣傳是為了跟另一條寫入路徑（toggleSetting）一致。
  static Future<MoodleUpdatePictureResult?> updateProfilePicture({
    required int draftItemId,
    bool delete = false,
  }) async {
    try {
      final result = await _callWs(
        updatePictureFunction,
        {
          "draftitemid": draftItemId.toString(),
          "delete": delete ? "1" : "0",
        },
        treatWarningsAsError: true,
      );
      return updatePictureResultOf(result);
    } catch (e, stack) {
      _reportAndRethrow(updatePictureFunction, e, stack);
    }
  }
}
